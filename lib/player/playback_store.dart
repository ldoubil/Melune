import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/lyrics/catalog.dart';
import 'package:melune/player/media_handler.dart';
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
  PlaybackStore({required this.bili, this.media, this.windows}) {
    media?.attach(this);
    windows?.attach(this);
    attachDesktopLyricHost(
      onClosed: closeDesktopLyricFromOverlay,
      onToggleLike: toggleLike,
      onToggleLock: toggleDesktopLyricLock,
    );
  }

  final BiliClient bili;
  final NowPlayingBridge? media;
  final NowPlayingBridge? windows;

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
  var _playing = false;
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
  String _desktopLyricSig = '';
  var _sessionEpoch = 0;
  var _forceSessionBump = false;
  String _sessionSig = '';
  var _ducked = false;
  var _pausedForFocus = false;
  final _random = Random();

  @override
  int get sessionEpoch => _sessionEpoch;

  @override
  MeluneTrack? get track => _queue.isEmpty ? null : _queue[_index];
  @override
  List<MeluneTrack> get queue => List.unmodifiable(_queue);
  List<MeluneLyricLine> get lyrics => List.unmodifiable(_lyrics);
  List<MeluneTrack> get recentTracks => List.unmodifiable(_recent);
  List<MeluneTrack> get likedTracks =>
      List.unmodifiable(_likedTracks.values);
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

  bool get desktopLyricOpen => _desktopLyricOpen;
  bool get desktopLyricLocked => _desktopLyricLocked;

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
    _loading = false;
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
    final player = _player;
    if (player == null) {
      await _startCurrent();
      return;
    }
    if (_playing) {
      await player.pause();
    } else {
      await _audioSession?.setActive(true);
      await player.play();
    }
  }

  @override
  void toggleLike() {
    toggleLikeTrack(track);
  }

  void toggleLikeTrack(MeluneTrack? item) {
    if (item == null) {
      return;
    }
    if (_likedTracks.containsKey(item.id)) {
      _likedTracks.remove(item.id);
    } else {
      _likedTracks[item.id] = item;
    }
    notifyListeners();
    _pushDesktopLyric(force: true);
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

  void toggleDesktopLyricLock() {
    if (!_desktopLyricOpen) {
      return;
    }
    _desktopLyricLocked = !_desktopLyricLocked;
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
    final signature =
        '$_desktopLyricOpen|$_desktopLyricLocked|$liked|$coverUrl|$previous|$current|$next';
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
    );
  }

  void cyclePlaybackMode() {
    _mode = PlaybackMode.values[(_mode.index + 1) % PlaybackMode.values.length];
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
    await _applyOutputVolume();
    notifyListeners();
  }

  Future<void> setQuality(int qualityId) async {
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
    if (_queue.isEmpty) {
      return;
    }
    if (shuffle && _queue.length > 1) {
      _index = _shuffledIndex();
    } else {
      _index = (_index + 1) % _queue.length;
    }
    await _startCurrent();
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
      await _player?.pause();
      return;
    }
    await next();
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
    if (shuffle && _queue.length > 1) {
      _index = _shuffledIndex();
    } else {
      _index = (_index - 1 + _queue.length) % _queue.length;
    }
    await _startCurrent();
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
    _loading = true;
    _error = null;
    if (!keepLyrics) {
      _lyrics.clear();
      _position = Duration.zero;
      _qualities.clear();
      _selectedQualityId = 0;
    }
    _duration = current.duration;
    _playing = false;
    notifyListeners();
    try {
      var playableTrack = current;
      if (_queue.length == 1 && current.cid == 0 && current.bvid.isNotEmpty) {
        final expanded = await bili.videoPages(current.bvid);
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
      final extracted = await bili.extractAudio(
        playableTrack,
        qualityId: _preferredQualityId,
      );
      final playable = extracted.track;
      _qualities
        ..clear()
        ..addAll(extracted.qualities);
      _selectedQualityId = extracted.selectedId;
      _queue[_index] = playable.copyWith(
        title: playable.title.isEmpty ? current.title : playable.title,
        albumTitle: playable.albumTitle.isEmpty ? current.albumTitle : playable.albumTitle,
      );
      final url = playable.audioUrl.isEmpty
          ? ''
          : await bili.proxyUrl(playable.audioUrl);
      if (url.isEmpty) {
        throw Exception('没有可播放的音频地址');
      }
      final player = await _ensurePlayer();
      await player.setUrl(
        url,
        headers: const {
          'Referer': 'https://www.bilibili.com',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125.0.0.0 Mobile Safari/537.36',
        },
      );
      await _applyOutputVolume();
      if (resumeAt != null && resumeAt > Duration.zero) {
        await player.seek(resumeAt);
        _position = resumeAt;
      }
      if (autoplay) {
        await _audioSession?.setActive(true);
        await player.play();
      }
      _remember(playable);
      if (!keepLyrics) {
        unawaited(_loadLyrics(_queue[_index]));
      }
    } catch (err) {
      _error = err.toString().replaceFirst('Exception: ', '');
      _playing = false;
    } finally {
      _loading = false;
      notifyListeners();
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
    _recent.removeWhere((item) => item.id == current.id || item.bvid == current.bvid);
    _recent.insert(0, current);
    if (_recent.length > 20) {
      _recent.removeLast();
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

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) {
      return existing;
    }
    await _bindAudioFocus();
    final player = AudioPlayer(handleInterruptions: false);
    _player = player;
    await _applyOutputVolume();
    _positionSub = player.positionStream.listen((value) {
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
      _playing = state.playing;
      if (state.playing) {
        unawaited(_audioSession?.setActive(true));
      }
      if (state.processingState == ProcessingState.completed) {
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
    unawaited(_positionSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_interruptionSub?.cancel());
    unawaited(_noisySub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
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
