import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/media3_bridge.dart'
    if (dart.library.html) 'package:melune/player/media3_bridge_stub.dart';

abstract class MediaSessionHost {
  MeluneTrack? get track;
  List<MeluneTrack> get queue;
  String get displayTitle;
  bool get playing;
  bool get loading;
  bool get liked;
  int get currentIndex;
  int get sessionEpoch;
  Duration get position;
  Duration get duration;

  Future<void> togglePlay();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration value);
  Future<void> playAt(int index);
  void toggleLike();
  void openNowPlaying({bool lyrics = false});
}

abstract class NowPlayingBridge {
  void attach(MediaSessionHost host);
  void detach();
  void syncFrom(MediaSessionHost host, {bool force = false});
}

class MeluneAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements NowPlayingBridge {
  MediaSessionHost? _host;
  var _epoch = -1;

  static final _favorite = MediaControl.custom(
    androidIcon: 'drawable/ic_media_favorite',
    label: '喜欢',
    name: 'favorite',
  );
  static final _lyrics = MediaControl.custom(
    androidIcon: 'drawable/ic_media_lyrics',
    label: '歌词',
    name: 'lyrics',
  );

  @override
  void attach(MediaSessionHost host) {
    _host = host;
    syncFrom(host, force: true);
  }

  @override
  void detach() {
    _host = null;
  }

  @override
  void syncFrom(MediaSessionHost host, {bool force = false}) {
    if (!force && host.sessionEpoch == _epoch) {
      return;
    }
    _epoch = host.sessionEpoch;
    final track = host.track;
    if (track == null) {
      mediaItem.add(null);
      queue.add(const []);
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.idle,
          updatePosition: Duration.zero,
          bufferedPosition: Duration.zero,
          queueIndex: 0,
          speed: 0,
        ),
      );
      return;
    }

    mediaItem.add(_mediaItemFor(host, track, current: true));
    queue.add([
      for (final item in host.queue) _mediaItemFor(host, item, current: false),
    ]);

    final playing = host.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          _favorite,
          _lyrics,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.fastForward,
          MediaAction.rewind,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: host.loading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: host.position,
        bufferedPosition: host.position,
        speed: playing ? 1.0 : 0.0,
        queueIndex: host.currentIndex,
      ),
    );
  }

  MediaItem _mediaItemFor(
    MediaSessionHost host,
    MeluneTrack track, {
    required bool current,
  }) {
    final cover = track.coverUrl.trim();
    return MediaItem(
      id: track.id,
      title: current ? host.displayTitle : track.title,
      artist: track.artist.isEmpty ? 'Bilibili 音乐' : track.artist,
      album: track.albumTitle.isEmpty ? 'Melune · 洛音' : track.albumTitle,
      duration: current
          ? (host.duration > Duration.zero ? host.duration : track.duration)
          : track.duration,
      artUri: cover.isEmpty ? null : Uri.tryParse(cover),
      playable: true,
    );
  }

  @override
  Future<void> play() async {
    final host = _host;
    if (host == null || host.playing) {
      return;
    }
    await host.togglePlay();
  }

  @override
  Future<void> pause() async {
    final host = _host;
    if (host == null || !host.playing) {
      return;
    }
    await host.togglePlay();
  }

  @override
  Future<void> seek(Duration position) async {
    await _host?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _host?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await _host?.previous();
  }

  @override
  Future<void> fastForward() async {
    await _host?.next();
  }

  @override
  Future<void> rewind() async {
    await _host?.previous();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _host?.playAt(index);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    final host = _host;
    if (host == null) {
      return;
    }
    switch (name) {
      case 'favorite':
        host.toggleLike();
      case 'lyrics':
        host.openNowPlaying(lyrics: true);
    }
  }

  @override
  Future<void> stop() async {
    final host = _host;
    if (host != null && host.playing) {
      await host.togglePlay();
    }
    await super.stop();
  }
}

Future<NowPlayingBridge?> bootstrapMediaSession() async {
  if (kIsWeb) {
    return null;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return bootstrapMedia3();
    case TargetPlatform.iOS:
      return AudioService.init<MeluneAudioHandler>(
        builder: MeluneAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'dev.melune.melune.audio',
          androidNotificationChannelName: '正在播放',
          androidNotificationChannelDescription: '锁屏、通知栏与系统媒体控制',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidResumeOnClick: true,
          preloadArtwork: true,
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
    default:
      return null;
  }
}
