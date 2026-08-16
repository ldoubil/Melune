import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:melune/player/cover_cache.dart';
import 'package:melune/player/media_handler.dart';

/// Android Media3 会话门面：只在 [MediaSessionHost.sessionEpoch] 变化时推一次状态，
/// 进度条交给系统按 1.0x 外推，不再每秒刷 PlaybackState。
class Media3NowPlayingBridge implements NowPlayingBridge {
  Media3NowPlayingBridge() {
    _channel.setMethodCallHandler(_onMethod);
  }

  static const _channel = MethodChannel('dev.melune.media3');

  MediaSessionHost? _host;
  var _epoch = -1;
  String? _coverUrl;
  String? _artworkPath;

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
    unawaited(_push(host));
  }

  Future<void> _push(MediaSessionHost host) async {
    final track = host.track;
    final cover = track?.coverUrl.trim() ?? '';
    final coverChanged = cover != _coverUrl;
    if (coverChanged) {
      _coverUrl = cover;
      _artworkPath = null;
    }
    try {
      await _channel.invokeMethod<void>('update', _payload(host));
    } catch (err) {
      debugPrint('Media3 会话推送失败: $err');
    }
    if (!coverChanged || cover.isEmpty) {
      return;
    }
    final path = await _cacheCover(cover);
    if (_coverUrl != cover) {
      return;
    }
    _artworkPath = path;
    try {
      await _channel.invokeMethod<void>('update', _payload(host));
    } catch (err) {
      debugPrint('Media3 封面推送失败: $err');
    }
  }

  Map<String, Object?> _payload(MediaSessionHost host) {
    final track = host.track;
    return {
      'enabled': track != null,
      'playing': host.playing,
      'loading': host.loading,
      'liked': host.liked,
      'positionMs': host.position.inMilliseconds,
      'durationMs': host.duration.inMilliseconds,
      'index': host.currentIndex,
      'id': track?.id ?? '',
      'title': host.displayTitle,
      'artist': (track?.artist.isEmpty ?? true) ? 'Bilibili 音乐' : track!.artist,
      'album': (track?.albumTitle.isEmpty ?? true)
          ? 'Melune · 洛音'
          : track!.albumTitle,
      'artworkPath': _artworkPath,
      'queue': [
        for (final item in host.queue)
          {
            'id': item.id,
            'title': item.title,
            'artist': item.artist.isEmpty ? 'Bilibili 音乐' : item.artist,
            'album':
                item.albumTitle.isEmpty ? 'Melune · 洛音' : item.albumTitle,
            'durationMs': item.duration.inMilliseconds,
          },
      ],
    };
  }

  Future<String?> _cacheCover(String url) async {
    if (url.isEmpty) {
      return null;
    }
    try {
      final file = await CoverCache.instance.ensure(url);
      return file?.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onMethod(MethodCall call) async {
    final host = _host;
    if (host == null) {
      return;
    }
    switch (call.method) {
      case 'play':
        if (!host.playing) {
          await host.togglePlay();
        }
      case 'pause':
        if (host.playing) {
          await host.togglePlay();
        }
      case 'next':
        await host.next();
      case 'previous':
        await host.previous();
      case 'seek':
        final ms = (call.arguments as num?)?.toInt() ?? 0;
        await host.seek(Duration(milliseconds: ms));
      case 'playAt':
        final index = (call.arguments as num?)?.toInt() ?? host.currentIndex;
        await host.playAt(index);
      case 'favorite':
        host.toggleLike();
      case 'lyrics':
        host.openNowPlaying(lyrics: true);
    }
  }
}

NowPlayingBridge? bootstrapMedia3() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  return Media3NowPlayingBridge();
}
