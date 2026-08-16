import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

const _coverUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

String normalizeCoverUrl(String url) {
  var out = url.trim();
  if (out.startsWith('//')) {
    return 'https:$out';
  }
  if (out.startsWith('http://')) {
    return 'https://${out.substring(7)}';
  }
  return out;
}

String sizedCoverUrl(String url) {
  final canonical = normalizeCoverUrl(url);
  final uri = Uri.tryParse(canonical);
  if (uri == null || !uri.hasScheme) {
    return canonical;
  }
  final host = uri.host.toLowerCase();
  if (!host.contains('hdslb.com') && !host.contains('biliimg.com')) {
    return canonical;
  }
  final path = uri.path.toLowerCase();
  if (path.contains('@') || path.endsWith('.gif')) {
    return canonical;
  }
  return '$canonical@400w_400h_1c.jpg';
}

class CoverCache extends ChangeNotifier {
  CoverCache._();

  static final CoverCache instance = CoverCache._();

  String? persistDir;
  final _inflight = <String, Future<File?>>{};

  void attach(String? dir) {
    if (persistDir == dir) {
      return;
    }
    persistDir = dir;
    notifyListeners();
  }

  File? existing(String url) {
    final canonical = normalizeCoverUrl(url);
    if (!_usable(canonical)) {
      return null;
    }
    final file = _fileOf(canonical);
    try {
      if (file.existsSync() && file.lengthSync() > 32) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<File?> ensure(String url) {
    final canonical = normalizeCoverUrl(url);
    if (!_usable(canonical)) {
      return Future<File?>.value(null);
    }
    final hit = existing(canonical);
    if (hit != null) {
      return Future<File?>.value(hit);
    }
    return _inflight.putIfAbsent(canonical, () {
      return _download(canonical).whenComplete(() => _inflight.remove(canonical));
    });
  }

  Future<File?> _download(String url) async {
    final candidates = <String>{
      sizedCoverUrl(url),
      url,
    }.where(_usable).toList();
    for (var attempt = 0; attempt < 3; attempt++) {
      final file = _fileOf(url);
      for (final candidate in candidates) {
        final got = await _fetchTo(file, candidate);
        if (got != null) {
          return got;
        }
      }
      final hit = existing(url);
      if (hit != null) {
        return hit;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 280 * (attempt + 1)));
      }
    }
    return existing(url);
  }

  Future<File?> _fetchTo(File file, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    final part = File('${file.path}.part');
    final client = HttpClient();
    client.userAgent = _coverUserAgent;
    client.connectionTimeout = const Duration(seconds: 10);
    client.idleTimeout = const Duration(seconds: 12);
    client.maxConnectionsPerHost = 8;
    client.autoUncompress = true;
    try {
      await file.parent.create(recursive: true);
      final response = await _getFollowingRedirects(client, uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }
      final sink = part.openWrite();
      try {
        await sink.addStream(response);
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (!part.existsSync() || part.lengthSync() < 32) {
        await _tryDelete(part);
        return null;
      }
      await _replace(part, file);
      if (!file.existsSync() || file.lengthSync() < 32) {
        return null;
      }
      return file;
    } catch (_) {
      await _tryDelete(part);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _getFollowingRedirects(
    HttpClient client,
    Uri start,
  ) async {
    var current = _httpsUri(start);
    for (var hop = 0; hop < 6; hop++) {
      final request = await client.getUrl(current);
      request.followRedirects = false;
      request.maxRedirects = 0;
      request.headers.set(HttpHeaders.refererHeader, 'https://www.bilibili.com');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      );
      final response = await request.close();
      final status = response.statusCode;
      if (status == 301 ||
          status == 302 ||
          status == 303 ||
          status == 307 ||
          status == 308) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) {
          return response;
        }
        current = _httpsUri(current.resolve(location));
        continue;
      }
      return response;
    }
    throw const HttpException('封面地址重定向过多');
  }

  Future<void> _replace(File src, File dest) async {
    try {
      if (dest.existsSync()) {
        await _tryDelete(dest);
      }
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      await _tryDelete(src);
    }
  }

  Future<void> _tryDelete(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  File _fileOf(String url) {
    return File('${_dir.path}${Platform.pathSeparator}${_name(url)}.img');
  }

  Directory get _dir {
    final base = persistDir;
    if (base != null && base.isNotEmpty) {
      return Directory('$base${Platform.pathSeparator}covers');
    }
    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}melune_covers',
    );
  }

  int usedBytes() {
    try {
      if (!_dir.existsSync()) {
        return 0;
      }
      var total = 0;
      for (final entity in _dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && !entity.path.endsWith('.part')) {
          total += entity.lengthSync();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearAll() async {
    try {
      if (_dir.existsSync()) {
        await _dir.delete(recursive: true);
      }
    } catch (_) {}
    _inflight.clear();
    notifyListeners();
  }

  static bool _usable(String url) {
    return url.startsWith('https://') || url.startsWith('http://');
  }

  static Uri _httpsUri(Uri uri) {
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }

  static String _name(String url) {
    var hash = 2166136261;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
