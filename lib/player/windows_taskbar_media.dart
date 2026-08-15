import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:melune/player/media_handler.dart';

class WindowsTaskbarMedia implements NowPlayingBridge {
  WindowsTaskbarMedia() {
    _channel.setMethodCallHandler(_onMethod);
  }

  static const _channel = MethodChannel('dev.melune.taskbar');

  MediaSessionHost? _host;
  String? _itemId;
  var _playing = false;
  var _liked = false;
  var _enabled = false;
  String? _coverUrl;
  var _title = '';

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
    unawaited(_sync(host, force: force));
  }

  Future<void> _sync(MediaSessionHost host, {required bool force}) async {
    final track = host.track;
    final enabled = track != null;
    final playing = host.playing;
    final liked = host.liked;
    final title = track == null
        ? 'Melune · 洛音'
        : '${host.displayTitle} · ${track.artist.isEmpty ? 'Bilibili 音乐' : track.artist}';
    final cover = track?.coverUrl.trim() ?? '';
    final same = !force &&
        track?.id == _itemId &&
        playing == _playing &&
        liked == _liked &&
        enabled == _enabled &&
        title == _title &&
        cover == _coverUrl;
    if (same) {
      return;
    }
    _itemId = track?.id;
    _playing = playing;
    _liked = liked;
    _enabled = enabled;
    _title = title;
    try {
      await _channel.invokeMethod<void>('update', {
        'enabled': enabled,
        'playing': playing,
        'liked': liked,
        'title': title,
      });
    } catch (_) {
      // 原生通道尚未就绪时忽略。
    }
    if (cover != _coverUrl) {
      _coverUrl = cover;
      unawaited(_pushArtwork(cover));
    }
  }

  Future<void> _pushArtwork(String url) async {
    Uint8List? bytes;
    if (url.isNotEmpty) {
      bytes = await _downloadCover(url);
    }
    if (url != _coverUrl) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('artwork', bytes ?? Uint8List(0));
    } catch (_) {
      // 原生通道尚未就绪时忽略。
    }
  }

  Future<Uint8List?> _downloadCover(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return null;
      }
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('Referer', 'https://www.bilibili.com');
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      client.close();
      return builder.takeBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _onMethod(MethodCall call) async {
    if (call.method != 'pressed') {
      return;
    }
    final host = _host;
    if (host == null) {
      return;
    }
    switch (call.arguments) {
      case 'previous':
        await host.previous();
        break;
      case 'playPause':
        await host.togglePlay();
        break;
      case 'next':
        await host.next();
        break;
      case 'like':
        host.toggleLike();
        break;
    }
  }
}

WindowsTaskbarMedia? bootstrapWindowsTaskbar() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return null;
  }
  return WindowsTaskbarMedia();
}
