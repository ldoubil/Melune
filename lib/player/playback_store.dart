import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/favorite_library.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/lyrics/catalog.dart';
import 'package:melune/player/media_handler.dart';
import 'package:melune/player/cover_cache.dart';
import 'package:melune/player/equalizer.dart';
import 'package:melune/player/offline_cache.dart';
import 'package:melune/settings/app_settings.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:melune/window/window_controller.dart';

enum PlaybackMode { sequential, shuffle, repeatOne, repeatAll }

extension PlaybackModeX on PlaybackMode {
  String get label => switch (this) {
    PlaybackMode.sequential => '顺序播放',
    PlaybackMode.shuffle => '随机播放',
    PlaybackMode.repeatOne => '单曲循环',
    PlaybackMode.repeatAll => '列表循环',
  };

  IconData get icon => switch (this) {
    PlaybackMode.sequential => Icons.repeat_rounded,
    PlaybackMode.shuffle => Icons.shuffle_rounded,
    PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlaybackMode.repeatAll => Icons.repeat_rounded,
  };

  bool get emphasized => this != PlaybackMode.sequential;
}

class PlaybackStore extends ChangeNotifier implements MediaSessionHost {
  PlaybackStore({required this.bili, this.media, this.windows, this.persistDir})
    : favorites = FavoriteLibrary(bili: bili),
      offline = OfflineCache(bili: bili, persistDir: persistDir) {
    media?.attach(this);
    windows?.attach(this);
    attachDesktopLyricHost(
      onClosed: closeDesktopLyricFromOverlay,
      onToggleLike: toggleLike,
      onToggleLock: toggleDesktopLyricLock,
      onCycleEffect: cycleDesktopLyricEffect,
    );
    CoverCache.instance.attach(persistDir);
    if ((persistDir ?? '').isNotEmpty) {
      _lifecycle = _PlaybackLifecycle(this)..attach();
    }
  }

  final BiliClient bili;
  final FavoriteLibrary favorites;
  final OfflineCache offline;
  final NowPlayingBridge? media;
  final NowPlayingBridge? windows;
  final String? persistDir;

  final List<MeluneTrack> _queue = [];
  final List<MeluneLyricLine> _lyrics = [];
  AudioPlayer? _player;
  AudioSession? _audioSession;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  int _index = 0;
  var _startGen = 0;
  var _playing = false;
  var _wantPlaying = false;
  var _loading = false;
  var _nowPlayingOpen = false;
  var _playlistOpen = false;
  var _lyricsExpanded = false;
  var _mode = PlaybackMode.sequential;
  var _position = Duration.zero;
  var _duration = Duration.zero;
  var _volume = 0.8;
  String? _error;
  final List<MeluneTrack> _recent = [];
  final Map<String, MeluneTrack> _likedTracks = {};
  final List<MeluneAudioQuality> _qualities = [];
  var _preferredQualityId = 0;
  var _selectedQualityId = 0;
  var _desktopLyricOpen = false;
  var _desktopLyricLocked = false;
  var _lyricEffect = DesktopLyricEffect.reel;
  String _desktopLyricSig = '';
  var _sessionEpoch = 0;
  var _forceSessionBump = false;
  String _sessionSig = '';
  var _ducked = false;
  var _pausedForFocus = false;
  AndroidEqualizer? _androidEq;
  final _random = Random();
  Timer? _persistTimer;
  _PlaybackLifecycle? _lifecycle;

  @override
  int get sessionEpoch => _sessionEpoch;

  @override
  MeluneTrack? get track => _queue.isEmpty ? null : _queue[_index];
  @override
  List<MeluneTrack> get queue => List.unmodifiable(_queue);
  List<MeluneLyricLine> get lyrics => List.unmodifiable(_lyrics);
  List<MeluneTrack> get recentTracks => List.unmodifiable(_recent);
  List<MeluneTrack> get likedTracks => List.unmodifiable(_likedTracks.values);
  @override
  bool get playing => _playing;
  @override
  bool get loading => _loading;
  @override
  bool get liked => isLiked(track);
  bool get nowPlayingOpen => _nowPlayingOpen;
  bool get playlistOpen => _playlistOpen;
  bool get lyricsExpanded => _lyricsExpanded;
  @override
  int get currentIndex => _index;
  PlaybackMode get playbackMode => _mode;
  bool get shuffle => _mode == PlaybackMode.shuffle;
  bool get repeatOne => _mode == PlaybackMode.repeatOne;
  @override
  Duration get position => _position;
  @override
  Duration get duration {
    if (_duration > Duration.zero) {
      return _duration;
    }
    return track?.duration ?? Duration.zero;
  }

  double get volume => _volume;
  String? get error => _error;
  List<MeluneAudioQuality> get qualities => List.unmodifiable(_qualities);
  int get selectedQualityId => _selectedQualityId;
  MeluneAudioQuality? get currentQuality {
    for (final item in _qualities) {
      if (item.id == _selectedQualityId) {
        return item;
      }
    }
    return _qualities.isEmpty ? null : _qualities.first;
  }

  String get qualityLabel => currentQuality?.label ?? '音质';
  int get preferredQualityId => _preferredQualityId;

  bool get desktopLyricOpen => _desktopLyricOpen;
  bool get desktopLyricLocked => _desktopLyricLocked;
  DesktopLyricEffect get lyricEffect => _lyricEffect;

  @override
  String get displayTitle {
    final current = track;
    if (current == null) {
      return '未在播放';
    }
    final cleaned = bili.cleanTitle(current.title);
    return cleaned.isEmpty ? current.title : cleaned;
  }

  bool isLiked(MeluneTrack? item) {
    return item != null && _likedTracks.containsKey(item.id);
  }

  int get activeLyricIndex {
    if (_lyrics.isEmpty) {
      return -1;
    }
    var index = 0;
    for (var i = 0; i < _lyrics.length; i++) {
      if (_position >= _lyrics[i].from) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  Future<void> cacheTracks(List<MeluneTrack> tracks) {
    return offline.enqueue(tracks, qualityId: _preferredQualityId);
  }

  Future<void> playTracks(List<MeluneTrack> tracks, {int start = 0}) async {
    if (tracks.isEmpty) {
      return;
    }
    _queue
      ..clear()
      ..addAll(tracks);
    _index = start.clamp(0, _queue.length - 1);
    await _startCurrent();
  }

  Future<void> playTrack(MeluneTrack item) {
    return playTracks([item]);
  }

  int enqueueTracks(List<MeluneTrack> tracks) {
    if (tracks.isEmpty) {
      return 0;
    }
    var added = 0;
    for (final item in tracks) {
      if (queueIndexOf(item) >= 0) {
        continue;
      }
      _queue.add(item);
      added++;
    }
    if (added > 0) {
      notifyListeners();
    }
    return added;
  }

  int enqueueAlbum(List<MeluneTrack> tracks) => enqueueTracks(tracks);

  bool isQueued(MeluneTrack? item) => queueIndexOf(item) >= 0;

  int queueIndexOf(MeluneTrack? item) {
    if (item == null) {
      return -1;
    }
    return _queue.indexWhere((entry) => _sameTrack(entry, item));
  }

  Future<void> toggleQueued(MeluneTrack item) async {
    final index = queueIndexOf(item);
    if (index >= 0) {
      await removeFromQueue(index);
      return;
    }
    enqueueTracks([item]);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    if (_queue.length == 1) {
      await clearQueue();
      return;
    }
    final removingCurrent = index == _index;
    _queue.removeAt(index);
    if (index < _index) {
      _index -= 1;
    } else if (_index >= _queue.length) {
      _index = _queue.length - 1;
    }
    if (removingCurrent && _player != null) {
      await _startCurrent();
      return;
    }
    notifyListeners();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    _index = 0;
    _playing = false;
    _wantPlaying = false;
    _loading = false;
    _startGen++;
    _lyrics.clear();
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    _qualities.clear();
    _selectedQualityId = 0;
    await _player?.stop();
    notifyListeners();
  }

  @override
  Future<void> togglePlay() async {
    if (track == null) {
      return;
    }
    _wantPlaying = !_playing;
    _playing = _wantPlaying;
    notifyListeners();
    if (_loading) {
      if (!_wantPlaying) {
        await _player?.pause();
      }
      return;
    }
    final player = _player;
    if (player == null) {
      await _startCurrent(
        autoplay: _wantPlaying,
        resumeAt: _position > Duration.zero ? _position : null,
      );
      return;
    }
    if (_wantPlaying) {
      await _audioSession?.setActive(true);
      await player.play();
      return;
    }
    await player.pause();
  }

  @override
  void toggleLike() {
    unawaited(toggleLikeTrack(track));
  }

  Future<void> toggleLikeTrack(MeluneTrack? item) async {
    if (item == null) {
      return;
    }
    final like = !isLiked(item);
    if (like) {
      _likedTracks[item.id] = item;
    } else {
      _likedTracks.remove(item.id);
    }
    notifyListeners();
    _pushDesktopLyric(force: true);
    try {
      await favorites.toggleDefault(item, like: like);
      await _syncLikeFromRemote(item);
    } catch (_) {}
  }

  Future<void> applyFavoriteFolders(
    MeluneTrack item,
    Set<int> folderIds,
  ) async {
    await favorites.applyFolders(item, folderIds);
    await _syncLikeFromRemote(item);
  }

  Future<void> _syncLikeFromRemote(MeluneTrack item) async {
    try {
      final inDefault = await favorites.isInDefault(item);
      if (inDefault) {
        _likedTracks[item.id] = item;
      } else {
        _likedTracks.remove(item.id);
      }
      notifyListeners();
      _pushDesktopLyric(force: true);
    } catch (_) {}
  }

  void openPlaylist() {
    _playlistOpen = true;
    _nowPlayingOpen = false;
    notifyListeners();
  }

  void closePlaylist() {
    _playlistOpen = false;
    notifyListeners();
  }

  void togglePlaylist() {
    if (_playlistOpen) {
      closePlaylist();
      return;
    }
    openPlaylist();
  }

  @override
  void openNowPlaying({bool lyrics = false}) {
    _nowPlayingOpen = true;
    _playlistOpen = false;
    _lyricsExpanded = lyrics;
    notifyListeners();
  }

  void closeNowPlaying() {
    _nowPlayingOpen = false;
    _lyricsExpanded = false;
    notifyListeners();
  }

  void toggleLyricsExpanded() {
    setLyricsExpanded(!_lyricsExpanded);
  }

  void setLyricsExpanded(bool value) {
    if (_lyricsExpanded == value) {
      return;
    }
    _lyricsExpanded = value;
    notifyListeners();
  }

  void toggleDesktopLyric() {
    if (!isDesktopWindow) {
      return;
    }
    _desktopLyricOpen = !_desktopLyricOpen;
    _pushDesktopLyric(force: true);
    notifyListeners();
  }

  void setDesktopLyricOpen(bool value) {
    if (!isDesktopWindow || _desktopLyricOpen == value) {
      return;
    }
    _desktopLyricOpen = value;
    _pushDesktopLyric(force: true);
    notifyListeners();
  }

  void toggleDesktopLyricLock() {
    if (!_desktopLyricOpen) {
      return;
    }
    _desktopLyricLocked = !_desktopLyricLocked;
    _pushDesktopLyric(force: true);
    AppSettings.instance.setLyricLocked(_desktopLyricLocked);
    notifyListeners();
  }

  void setDesktopLyricLocked(bool value) {
    if (_desktopLyricLocked == value) {
      return;
    }
    _desktopLyricLocked = value;
    _pushDesktopLyric(force: true);
    AppSettings.instance.setLyricLocked(value);
    notifyListeners();
  }

  void cycleDesktopLyricEffect() {
    final values = DesktopLyricEffect.values;
    setDesktopLyricEffect(values[(_lyricEffect.index + 1) % values.length]);
  }

  void setDesktopLyricEffect(DesktopLyricEffect effect) {
    if (_lyricEffect == effect) {
      return;
    }
    _lyricEffect = effect;
    AppSettings.instance.setLyricEffect(effect);
    _pushDesktopLyric(force: true);
    notifyListeners();
  }

  void hideDesktopLyric() {
    if (!_desktopLyricOpen) {
      return;
    }
    _desktopLyricOpen = false;
    _pushDesktopLyric(force: true);
    notifyListeners();
  }

  void closeDesktopLyricFromOverlay() {
    if (!_desktopLyricOpen) {
      return;
    }
    _desktopLyricOpen = false;
    notifyListeners();
  }

  double get lyricLineProgress {
    final index = activeLyricIndex;
    if (index < 0 || index >= _lyrics.length) {
      return 0;
    }
    final line = _lyrics[index];
    final total = line.to.inMilliseconds - line.from.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return ((_position.inMilliseconds - line.from.inMilliseconds) / total)
        .clamp(0.0, 1.0);
  }

  void _pushDesktopLyric({bool force = false}) {
    if (!_desktopLyricOpen && !force) {
      return;
    }
    final index = activeLyricIndex;
    final current = (index >= 0 && index < _lyrics.length)
        ? _lyrics[index].content
        : displayTitle;
    final previous = (index > 0 && index < _lyrics.length)
        ? _lyrics[index - 1].content
        : '';
    final next = (index >= 0 && index + 1 < _lyrics.length)
        ? _lyrics[index + 1].content
        : '';
    final coverUrl = track?.coverUrl ?? '';
    final progress = lyricLineProgress;
    final progressBucket = _lyricEffect == DesktopLyricEffect.karaoke
        ? (progress * 40).round()
        : 0;
    final opacity = AppSettings.instance.lyricOpacity;
    final signature =
        '$_desktopLyricOpen|$_desktopLyricLocked|$liked|$coverUrl|$previous|$current|$next|${_lyricEffect.name}|$progressBucket|$opacity';
    if (!force && signature == _desktopLyricSig) {
      return;
    }
    _desktopLyricSig = signature;
    syncDesktopLyric(
      visible: _desktopLyricOpen,
      locked: _desktopLyricLocked,
      liked: liked,
      coverUrl: coverUrl,
      previous: previous,
      current: current,
      next: next,
      title: displayTitle,
      effect: _lyricEffect,
      progress: progress,
      opacity: opacity,
    );
  }

  void cyclePlaybackMode() {
    setPlaybackMode(
      PlaybackMode.values[(_mode.index + 1) % PlaybackMode.values.length],
    );
  }

  void setPlaybackMode(PlaybackMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    AppSettings.instance.setPlaybackModeIndex(mode.index);
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    final total = duration.inMilliseconds;
    _position = Duration(milliseconds: value.inMilliseconds.clamp(0, total));
    _pushDesktopLyric();
    _forceSessionBump = true;
    notifyListeners();
    await _player?.seek(_position);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    AppSettings.instance.setVolume(_volume);
    await _applyOutputVolume();
    notifyListeners();
  }

  Future<void> setQuality(int qualityId) async {
    AppSettings.instance.setPreferredQualityId(qualityId);
    if (track == null || (qualityId == _selectedQualityId && qualityId != 0)) {
      _preferredQualityId = qualityId;
      notifyListeners();
      return;
    }
    _preferredQualityId = qualityId;
    await _startCurrent(
      resumeAt: _position,
      keepLyrics: true,
      autoplay: _playing,
    );
  }

  @override
  Future<void> next() async {
    await _skipTo(_nextIndex(), autoplay: true);
  }

  Future<void> _advanceFromCompletion() async {
    if (_queue.isEmpty) {
      return;
    }
    if (_mode == PlaybackMode.repeatOne) {
      await _restartCurrent();
      return;
    }
    if (_mode == PlaybackMode.sequential && _index >= _queue.length - 1) {
      _wantPlaying = false;
      _playing = false;
      notifyListeners();
      await _player?.pause();
      return;
    }
    await _skipTo(_nextIndex(), autoplay: true);
  }

  @override
  Future<void> previous() async {
    if (_queue.isEmpty) {
      return;
    }
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    await _skipTo(_previousIndex(), autoplay: true);
  }

  int _nextIndex() {
    if (_queue.isEmpty) {
      return 0;
    }
    if (shuffle && _queue.length > 1) {
      return _shuffledIndex();
    }
    return (_index + 1) % _queue.length;
  }

  int _previousIndex() {
    if (_queue.isEmpty) {
      return 0;
    }
    if (shuffle && _queue.length > 1) {
      return _shuffledIndex();
    }
    return (_index - 1 + _queue.length) % _queue.length;
  }

  Future<void> _skipTo(int index, {required bool autoplay}) async {
    if (_queue.isEmpty) {
      return;
    }
    _index = index;
    await _startCurrent(autoplay: autoplay);
  }

  @override
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    _index = index;
    await _startCurrent();
  }

  Future<void> _startCurrent({
    Duration? resumeAt,
    bool keepLyrics = false,
    bool autoplay = true,
  }) async {
    final current = track;
    if (current == null) {
      return;
    }
    final gen = ++_startGen;
    _loading = true;
    _error = null;
    _wantPlaying = autoplay;
    _playing = autoplay;
    if (!autoplay) {
      await _player?.pause();
    }
    if (!keepLyrics) {
      _lyrics.clear();
      if (resumeAt == null) {
        _position = Duration.zero;
      }
      _qualities.clear();
      _selectedQualityId = 0;
    }
    _duration = current.duration;
    notifyListeners();
    try {
      var playableTrack = current;
      if (_queue.length == 1 && current.cid == 0 && current.bvid.isNotEmpty) {
        final expanded = await bili.videoPages(current.bvid);
        if (gen != _startGen) {
          return;
        }
        if (expanded.length > 1) {
          _queue
            ..clear()
            ..addAll(expanded);
          _index = 0;
          playableTrack = expanded.first;
        } else if (expanded.isNotEmpty) {
          playableTrack = expanded.first;
          _queue[0] = playableTrack;
        }
      }
      final local = offline.fileFor(playableTrack);
      if (local != null) {
        final player = await _ensurePlayer();
        if (gen != _startGen) {
          return;
        }
        await player.setFilePath(local.path);
        if (gen != _startGen) {
          return;
        }
        await _applyOutputVolume();
        if (resumeAt != null && resumeAt > Duration.zero) {
          await player.seek(resumeAt);
          _position = resumeAt;
        }
        if (gen != _startGen) {
          return;
        }
        if (_wantPlaying) {
          await _audioSession?.setActive(true);
          unawaited(player.play());
          _playing = true;
        } else {
          unawaited(player.pause());
          _playing = false;
        }
        _loading = false;
        _remember(playableTrack);
        notifyListeners();
        unawaited(_syncLikeFromRemote(_queue[_index]));
        if (!keepLyrics) {
          unawaited(_loadLyrics(_queue[_index]));
        }
        return;
      }
      final extracted = await bili.extractAudio(
        playableTrack,
        qualityId: _preferredQualityId,
      );
      if (gen != _startGen) {
        return;
      }
      final playable = extracted.track;
      _qualities
        ..clear()
        ..addAll(extracted.qualities);
      _selectedQualityId = extracted.selectedId;
      _queue[_index] = playable.copyWith(
        title: playable.title.isEmpty ? current.title : playable.title,
        albumTitle: playable.albumTitle.isEmpty
            ? current.albumTitle
            : playable.albumTitle,
      );
      final url = playable.audioUrl.isEmpty
          ? ''
          : await bili.proxyUrl(playable.audioUrl);
      if (url.isEmpty) {
        throw Exception('没有可播放的音频地址');
      }
      final player = await _ensurePlayer();
      if (gen != _startGen) {
        return;
      }
      await player.setUrl(url);
      if (gen != _startGen) {
        return;
      }
      await _applyOutputVolume();
      if (resumeAt != null && resumeAt > Duration.zero) {
        await player.seek(resumeAt);
        _position = resumeAt;
      }
      if (gen != _startGen) {
        return;
      }
      if (_wantPlaying) {
        await _audioSession?.setActive(true);
        unawaited(player.play());
        _playing = true;
      } else {
        unawaited(player.pause());
        _playing = false;
      }
      _loading = false;
      _remember(playable);
      notifyListeners();
      unawaited(_syncLikeFromRemote(_queue[_index]));
      if (!keepLyrics) {
        unawaited(_loadLyrics(_queue[_index]));
      }
    } catch (err) {
      if (gen != _startGen) {
        return;
      }
      _error = err.toString().replaceFirst('Exception: ', '');
      _playing = false;
      _wantPlaying = false;
    } finally {
      if (gen == _startGen) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadLyrics(MeluneTrack current) async {
    try {
      var lines = await bili.officialLyrics(current.bvid, current.cid);
      if (lines.length < 3) {
        final title = bili.cleanTitle(current.title);
        final catalog = await matchCatalogLyrics(
          title: title.isEmpty ? current.title : title,
          artist: current.artist,
          duration: duration > Duration.zero ? duration : current.duration,
        );
        if (catalog.length > lines.length) {
          lines = catalog;
        }
      }
      if (track?.id != current.id) {
        return;
      }
      _lyrics
        ..clear()
        ..addAll(lines);
      _pushDesktopLyric(force: true);
      notifyListeners();
    } catch (_) {
      // 没有可对齐的歌词时保持空列表，界面会提示清洗后的歌名。
    }
  }

  void _remember(MeluneTrack current) {
    _recent.removeWhere(
      (item) => item.id == current.id || item.bvid == current.bvid,
    );
    _recent.insert(0, current);
    if (_recent.length > 80) {
      _recent.removeRange(80, _recent.length);
    }
  }

  Future<void> _bindAudioFocus() async {
    if (_audioSession != null) {
      return;
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _audioSession = session;
    _interruptionSub = session.interruptionEventStream.listen((event) {
      unawaited(_onAudioInterruption(event));
    });
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      unawaited(_player?.pause());
    });
  }

  Future<void> _onAudioInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _ducked = true;
          await _applyOutputVolume();
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_playing) {
            _pausedForFocus = true;
            await _player?.pause();
          }
      }
      return;
    }
    switch (event.type) {
      case AudioInterruptionType.duck:
        _ducked = false;
        await _applyOutputVolume();
      case AudioInterruptionType.pause:
      case AudioInterruptionType.unknown:
        if (_pausedForFocus) {
          _pausedForFocus = false;
          await _player?.play();
        }
    }
  }

  Future<void> _applyOutputVolume() async {
    final output = _ducked ? _volume * 0.2 : _volume;
    await _player?.setVolume(output);
  }

  Future<void> _applySkipSilence() async {
    try {
      await _player?.setSkipSilenceEnabled(AppSettings.instance.skipSilence);
    } catch (_) {}
  }

  Future<void> applyOutputSettings() async {
    await _applySkipSilence();
    await MeluneEqualizer.applyFromSettings(android: _androidEq);
    _pushDesktopLyric(force: true);
    notifyListeners();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) {
      return existing;
    }
    await _bindAudioFocus();
    AudioPipeline? pipeline;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _androidEq = AndroidEqualizer();
      pipeline = AudioPipeline(androidAudioEffects: [_androidEq!]);
    }
    final player = AudioPlayer(
      handleInterruptions: false,
      useProxyForRequestHeaders: false,
      audioPipeline: pipeline,
    );
    _player = player;
    await _applyOutputVolume();
    await _applySkipSilence();
    unawaited(MeluneEqualizer.applyFromSettings(android: _androidEq));
    _positionSub = player.positionStream.listen((value) {
      if (_loading && value > Duration.zero) {
        _loading = false;
      }
      if (value <= Duration.zero &&
          _playing &&
          _position > const Duration(seconds: 2)) {
        return;
      }
      _position = value;
      _pushDesktopLyric();
      notifyListeners();
    });
    _durationSub = player.durationStream.listen((value) {
      if (value != null && value > Duration.zero) {
        _duration = value;
        notifyListeners();
      }
    });
    _stateSub = player.playerStateStream.listen((state) {
      if (state.playing) {
        _playing = true;
        _wantPlaying = true;
        if (_loading) {
          _loading = false;
        }
        unawaited(_audioSession?.setActive(true));
      } else if (!_loading) {
        _playing = false;
        _wantPlaying = false;
      }
      if (!_loading && state.processingState == ProcessingState.completed) {
        unawaited(_advanceFromCompletion());
      }
      notifyListeners();
    });
    return player;
  }

  Future<void> _restartCurrent() async {
    await _player?.seek(Duration.zero);
    await _player?.play();
  }

  int _shuffledIndex() {
    if (_queue.length <= 1) {
      return _index;
    }
    var nextIndex = _random.nextInt(_queue.length);
    while (nextIndex == _index) {
      nextIndex = _random.nextInt(_queue.length);
    }
    return nextIndex;
  }

  bool _sameTrack(MeluneTrack a, MeluneTrack b) {
    if (a.id == b.id) {
      return true;
    }
    if (a.bvid.isEmpty || a.bvid != b.bvid) {
      return false;
    }
    return a.cid == 0 || b.cid == 0 || a.cid == b.cid;
  }

  @override
  void notifyListeners() {
    _refreshSessionEpoch();
    super.notifyListeners();
    media?.syncFrom(this);
    windows?.syncFrom(this);
    _schedulePersist();
  }

  File? get _persistFile {
    final dir = persistDir;
    if (dir == null || dir.isEmpty) {
      return null;
    }
    return File('$dir${Platform.pathSeparator}playback.json');
  }

  void _schedulePersist() {
    if (_persistFile == null) {
      return;
    }
    _persistTimer ??= Timer(const Duration(seconds: 4), persistNow);
  }

  void persistNow() {
    _persistTimer?.cancel();
    _persistTimer = null;
    _persistNow();
  }

  Future<void> restore() async {
    await offline.restore();
    final file = _persistFile;
    if (file == null || !file.existsSync()) {
      return;
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) {
        return;
      }
      final queue = (raw['queue'] as List? ?? [])
          .map(MeluneTrack.tryParse)
          .whereType<MeluneTrack>()
          .toList();
      final recent = (raw['recent'] as List? ?? [])
          .map(MeluneTrack.tryParse)
          .whereType<MeluneTrack>()
          .toList();
      final liked = (raw['liked'] as List? ?? [])
          .map(MeluneTrack.tryParse)
          .whereType<MeluneTrack>();
      _recent
        ..clear()
        ..addAll(recent);
      _likedTracks
        ..clear()
        ..addEntries(liked.map((item) => MapEntry(item.id, item)));
      _preferredQualityId = AppSettings.instance.preferredQualityId;
      if (queue.isEmpty) {
        _volume = ((raw['volume'] as num?)?.toDouble() ??
                AppSettings.instance.volume)
            .clamp(0.0, 1.0);
        final modeIndex =
            (raw['mode'] as num?)?.toInt() ??
            AppSettings.instance.playbackModeIndex;
        if (modeIndex >= 0 && modeIndex < PlaybackMode.values.length) {
          _mode = PlaybackMode.values[modeIndex];
        }
        notifyListeners();
        return;
      }
      _queue
        ..clear()
        ..addAll(queue);
      _index = ((raw['index'] as num?)?.toInt() ?? 0).clamp(
        0,
        _queue.length - 1,
      );
      _position = Duration(
        milliseconds: (raw['positionMs'] as num?)?.toInt() ?? 0,
      );
      _duration = track?.duration ?? Duration.zero;
      _volume = ((raw['volume'] as num?)?.toDouble() ?? _volume).clamp(
        0.0,
        1.0,
      );
      final modeIndex = (raw['mode'] as num?)?.toInt() ?? 0;
      if (modeIndex >= 0 && modeIndex < PlaybackMode.values.length) {
        _mode = PlaybackMode.values[modeIndex];
      }
      _desktopLyricOpen =
          AppSettings.instance.desktopLyricOnStart ||
          raw['desktopLyricOpen'] == true;
      _desktopLyricLocked =
          AppSettings.instance.lyricLocked || raw['desktopLyricLocked'] == true;
      _lyricEffect = AppSettings.instance.lyricEffect;
      if (_lyricEffect == DesktopLyricEffect.reel) {
        _lyricEffect = DesktopLyricEffect.parse(raw['lyricEffect']);
      }
      _playing = false;
      _wantPlaying = false;
      _loading = false;
      notifyListeners();
      _pushDesktopLyric(force: true);
      if (AppSettings.instance.resumeAutoplay) {
        await _startCurrent(resumeAt: _position, autoplay: true);
      }
    } catch (_) {}
  }

  void _persistNow() {
    final file = _persistFile;
    if (file == null) {
      return;
    }
    try {
      file.writeAsStringSync(
        jsonEncode({
          'index': _index,
          'positionMs': _position.inMilliseconds,
          'volume': _volume,
          'mode': _mode.index,
          'desktopLyricOpen': _desktopLyricOpen,
          'desktopLyricLocked': _desktopLyricLocked,
          'lyricEffect': _lyricEffect.name,
          'queue': _queue.map((item) => item.toJson()).toList(),
          'recent': _recent.map((item) => item.toJson()).toList(),
          'liked': _likedTracks.values.map((item) => item.toJson()).toList(),
        }),
        flush: true,
      );
    } catch (_) {}
  }

  void _refreshSessionEpoch() {
    final sig = [
      track?.id ?? '',
      _playing,
      _loading,
      liked,
      duration.inMilliseconds,
      _index,
      _queue.map((item) => item.id).join(','),
    ].join('|');
    if (_forceSessionBump || sig != _sessionSig) {
      _sessionSig = sig;
      _sessionEpoch++;
      _forceSessionBump = false;
    }
  }

  @override
  void dispose() {
    media?.detach();
    windows?.detach();
    if (_desktopLyricOpen) {
      _desktopLyricOpen = false;
      _pushDesktopLyric(force: true);
    }
    _lifecycle?.detach();
    _lifecycle = null;
    persistNow();
    favorites.dispose();
    offline.dispose();
    unawaited(_positionSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_interruptionSub?.cancel());
    unawaited(_noisySub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }
}

class _PlaybackLifecycle with WidgetsBindingObserver {
  _PlaybackLifecycle(this._store);

  final PlaybackStore _store;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _store.persistNow();
    }
  }
}

class PlaybackScope extends InheritedNotifier<PlaybackStore> {
  const PlaybackScope({
    super.key,
    required PlaybackStore store,
    required super.child,
  }) : super(notifier: store);

  static PlaybackStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlaybackScope>();
    assert(scope != null, 'PlaybackScope not found');
    return scope!.notifier!;
  }

  static PlaybackStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PlaybackScope>();
    assert(scope != null, 'PlaybackScope not found');
    return scope!.notifier!;
  }
}
