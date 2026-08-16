import 'dart:async';
import 'dart:io';

class CoverCache {
  CoverCache._();

  static final CoverCache instance = CoverCache._();

  String? persistDir;
  final _inflight = <String, Future<File?>>{};

  void attach(String? dir) {
    persistDir = dir;
  }

  File? existing(String url) {
    if (!_usable(url)) {
      return null;
    }
    final file = _fileOf(url);
    try {
      if (file.existsSync() && file.lengthSync() > 32) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<File?> ensure(String url) {
    if (!_usable(url)) {
      return Future<File?>.value(null);
    }
    final hit = existing(url);
    if (hit != null) {
      return Future<File?>.value(hit);
    }
    return _inflight.putIfAbsent(url, () {
      return _download(url).whenComplete(() => _inflight.remove(url));
    });
  }

  Future<File?> _download(String url) async {
    final file = _fileOf(url);
    final part = File('${file.path}.part');
    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';
    try {
      await file.parent.create(recursive: true);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Referer', 'https://www.bilibili.com');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final sink = part.openWrite();
      await response.pipe(sink);
      await sink.close();
      if (!part.existsSync() || part.lengthSync() < 32) {
        try {
          await part.delete();
        } catch (_) {}
        return null;
      }
      if (file.existsSync()) {
        await file.delete();
      }
      await part.rename(file.path);
      return file;
    } catch (_) {
      try {
        if (part.existsSync()) {
          await part.delete();
        }
      } catch (_) {}
      return existing(url);
    } finally {
      client.close(force: true);
    }
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
        if (entity is File) {
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
  }

  static bool _usable(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
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
