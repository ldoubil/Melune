import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/settings/app_settings.dart';

class OfflineJob {
  const OfflineJob({required this.track, this.progress = 0, this.error});

  final MeluneTrack track;
  final double progress;
  final String? error;

  OfflineJob copyWith({double? progress, String? error}) {
    return OfflineJob(
      track: track,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class OfflineEntry {
  const OfflineEntry({required this.track, required this.filePath});

  final MeluneTrack track;
  final String filePath;
}

class OfflineCache extends ChangeNotifier {
  OfflineCache({required this.bili, this.persistDir});

  final BiliClient bili;
  final String? persistDir;

  final Map<String, OfflineEntry> _entries = {};
  final Map<String, OfflineJob> _jobs = {};
  final List<String> _queue = [];
  final Map<String, HttpClientRequest> _requests = {};
  var _running = 0;
  var _gen = 0;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  static const _parallel = 2;

  List<MeluneTrack> get tracks => [
    for (final entry in _entries.values) entry.track,
  ];

  List<OfflineJob> get jobs => _jobs.values.toList(growable: false);

  int get cachedCount => _entries.length;

  int get activeCount => _jobs.length + _queue.length;

  bool get busy => _jobs.isNotEmpty || _queue.isNotEmpty;

  bool isCached(MeluneTrack track) => _entries.containsKey(_key(track));

  bool isQueued(MeluneTrack track) {
    final key = _key(track);
    return _jobs.containsKey(key) || _queue.contains(key);
  }

  double? progressOf(MeluneTrack track) => _jobs[_key(track)]?.progress;

  String? errorOf(MeluneTrack track) => _jobs[_key(track)]?.error;

  File? fileFor(MeluneTrack track) {
    final entry = _entries[_key(track)];
    if (entry == null) {
      return null;
    }
    final file = File(entry.filePath);
    return file.existsSync() ? file : null;
  }

  (int done, int total) albumProgress(List<MeluneTrack> tracks) {
    var done = 0;
    for (final track in tracks) {
      if (isCached(track)) {
        done += 1;
      }
    }
    return (done, tracks.length);
  }

  bool albumCached(List<MeluneTrack> tracks) {
    if (tracks.isEmpty) {
      return false;
    }
    return tracks.every(isCached);
  }

  Future<void> restore() async {
    final file = File('${_dir.path}${Platform.pathSeparator}index.json');
    if (!file.existsSync()) {
      return;
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) {
        return;
      }
      final items = raw['items'] as List? ?? const [];
      _entries.clear();
      for (final item in items) {
        if (item is! Map) {
          continue;
        }
        final track = MeluneTrack.tryParse(item['track']);
        final path = item['path'] as String? ?? '';
        if (track == null || path.isEmpty) {
          continue;
        }
        final audio = File(path);
        if (!audio.existsSync()) {
          continue;
        }
        _entries[_key(track)] = OfflineEntry(track: track, filePath: path);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> enqueue(List<MeluneTrack> tracks, {int qualityId = 0}) async {
    var added = false;
    for (final track in tracks) {
      final key = _key(track);
      if (key.isEmpty || isCached(track)) {
        continue;
      }
      final existing = _jobs[key];
      if (existing != null && existing.error == null) {
        continue;
      }
      if (!_queue.contains(key)) {
        _queue.add(key);
        _jobs[key] = OfflineJob(track: track);
        added = true;
      }
    }
    if (!added) {
      return;
    }
    notifyListeners();
    await _pump(qualityId: qualityId);
  }

  Future<void> remove(MeluneTrack track) async {
    final key = _key(track);
    _queue.remove(key);
    final request = _requests.remove(key);
    request?.abort();
    _jobs.remove(key);
    final entry = _entries.remove(key);
    if (entry != null) {
      try {
        await File(entry.filePath).delete();
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeAll(List<MeluneTrack> tracks) async {
    for (final track in tracks) {
      await remove(track);
    }
  }

  Future<void> _pump({required int qualityId}) async {
    while (_running < _parallel && _queue.isNotEmpty) {
      final key = _queue.removeAt(0);
      _running += 1;
      unawaited(
        _download(key, qualityId: qualityId).whenComplete(() {
          _running -= 1;
          unawaited(_pump(qualityId: qualityId));
        }),
      );
    }
  }

  Future<void> _download(String key, {required int qualityId}) async {
    final job = _jobs[key];
    if (job == null) {
      return;
    }
    final track = job.track;
    final gen = ++_gen;
    try {
      _setJob(key, job.copyWith(progress: 0.02));
      final extracted = await bili.extractAudio(track, qualityId: qualityId);
      var url = extracted.track.audioUrl;
      if (url.isEmpty) {
        url = extracted.selected?.audioUrl ?? '';
      }
      if (url.isEmpty) {
        throw Exception('没有可下载的音频地址');
      }
      final file = File('${_audioDir.path}${Platform.pathSeparator}$key.m4a');
      await file.parent.create(recursive: true);
      if (url.startsWith('melune-fake:')) {
        await file.writeAsBytes(_silentWav(), flush: true);
      } else {
        final proxied = await bili.proxyUrl(url);
        await _fetch(key, proxied, file);
      }
      if (_jobs[key] == null) {
        try {
          await file.delete();
        } catch (_) {}
        return;
      }
      _entries[key] = OfflineEntry(track: track, filePath: file.path);
      _jobs.remove(key);
      await _persist();
      await enforceLimit();
      notifyListeners();
    } catch (err) {
      if (gen != _gen && _jobs[key] == null) {
        return;
      }
      _jobs[key] = OfflineJob(
        track: track,
        error: err.toString().replaceFirst('Exception: ', ''),
      );
      notifyListeners();
    }
  }

  Future<void> _fetch(String key, String url, File file) async {
    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Referer', 'https://www.bilibili.com');
      _requests[key] = request;
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('下载失败 ${response.statusCode}');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in response) {
        if (_jobs[key] == null) {
          await sink.close();
          await file.delete();
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        final progress = total > 0 ? (received / total).clamp(0.02, 0.99) : 0.5;
        _setJob(key, _jobs[key]!.copyWith(progress: progress), throttle: true);
      }
      await sink.flush();
      await sink.close();
    } finally {
      _requests.remove(key);
      client.close(force: true);
    }
  }

  void _setJob(String key, OfflineJob job, {bool throttle = false}) {
    if (_jobs[key] == null) {
      return;
    }
    _jobs[key] = job;
    if (!throttle) {
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds < 180) {
      return;
    }
    _lastNotify = now;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _dir.create(recursive: true);
      final file = File('${_dir.path}${Platform.pathSeparator}index.json');
      await file.writeAsString(
        jsonEncode({
          'items': [
            for (final entry in _entries.values)
              {'path': entry.filePath, 'track': entry.track.toJson()},
          ],
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Directory get _dir {
    final custom = AppSettings.instance.effectiveOfflineDir;
    if (custom.isNotEmpty) {
      return Directory(custom);
    }
    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}melune_offline',
    );
  }

  Directory get _audioDir =>
      Directory('${_dir.path}${Platform.pathSeparator}audio');

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

  Future<void> enforceLimit() async {
    final maxMb = AppSettings.instance.offlineMaxMb;
    if (maxMb <= 0) {
      return;
    }
    final limit = maxMb * 1024 * 1024;
    var total = usedBytes();
    if (total <= limit) {
      return;
    }
    final oldest = _entries.values.toList()
      ..sort((a, b) {
        final aTime = File(a.filePath).existsSync()
            ? File(a.filePath).lastModifiedSync()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = File(b.filePath).existsSync()
            ? File(b.filePath).lastModifiedSync()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    for (final entry in oldest) {
      if (total <= limit) {
        break;
      }
      final file = File(entry.filePath);
      var size = 0;
      try {
        if (file.existsSync()) {
          size = file.lengthSync();
          await file.delete();
        }
      } catch (_) {}
      _entries.removeWhere((key, value) => value.filePath == entry.filePath);
      total -= size;
    }
    await _persist();
    notifyListeners();
  }

  static String _key(MeluneTrack track) {
    final raw = track.id.isNotEmpty ? track.id : '${track.bvid}_${track.cid}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  static Uint8List _silentWav() {
    const samples = 400;
    const dataSize = samples * 2;
    final bytes = Uint8List(44 + dataSize);
    final view = ByteData.sublistView(bytes);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes[offset + i] = text.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    view.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, 8000, Endian.little);
    view.setUint32(28, 16000, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    view.setUint32(40, dataSize, Endian.little);
    return bytes;
  }
}
