import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 选出应用私有、原生层也能写的目录，避免 Uri.resolve 把路径解析到沙箱外。
///
/// 永远不要落到临时目录：系统会清缓存，登录态就会时有时无。
Future<String> resolveBiliCookieDir() async {
  final candidates = <Directory>[];
  Future<void> add(Future<Directory> Function() locate, {bool nestBili = true}) async {
    try {
      final root = (await locate()).path;
      candidates.add(
        Directory(nestBili ? '$root${Platform.pathSeparator}bili' : root),
      );
    } catch (_) {}
  }

  await add(getApplicationSupportDirectory);
  await add(getApplicationDocumentsDirectory);
  await add(getApplicationSupportDirectory, nestBili: false);

  final seen = <String>{};
  final unique = <Directory>[];
  for (final dir in candidates) {
    if (seen.add(dir.path)) {
      unique.add(dir);
    }
  }

  final errors = <String>[];
  Directory? writable;
  Directory? created;
  Directory? withCookies;
  for (final dir in unique) {
    try {
      await prepareCookieDir(dir);
      created ??= dir;
      if (!await probeCookieDirWritable(dir)) {
        errors.add('${dir.path}: 无法写入');
        continue;
      }
      writable ??= dir;
      final cookies = File('${dir.path}${Platform.pathSeparator}cookies.json');
      if (await cookies.exists() && await cookies.length() > 2) {
        withCookies ??= dir;
      }
    } catch (err) {
      errors.add('${dir.path}: $err');
    }
  }

  Directory? cacheBili;
  try {
    cacheBili = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}bili',
    );
  } catch (_) {}
  if (withCookies == null && cacheBili != null) {
    final cached = File(
      '${cacheBili.path}${Platform.pathSeparator}cookies.json',
    );
    if (await cached.exists() && await cached.length() > 2) {
      withCookies = cacheBili;
    }
  }

  // 沙箱目录探测偶发会误判；应用私有路径只要能建出来就先用，不能把启动卡死。
  final chosen = writable ?? created ?? withCookies;
  if (chosen == null) {
    throw Exception(
      errors.isEmpty ? '没有可用的应用目录' : '没有可写的 cookie 目录\n${errors.join('\n')}',
    );
  }
  if (writable != null &&
      withCookies != null &&
      writable.path != withCookies.path) {
    await _copyIfMissing(withCookies, writable, 'cookies.json');
    await _copyIfMissing(withCookies, writable, 'user.json');
    await _copyIfMissing(withCookies, writable, 'playback.json');
    return writable.path;
  }
  return chosen.path;
}

Future<void> prepareCookieDir(Directory dir) async {
  try {
    if (await FileSystemEntity.isFile(dir.path)) {
      final leftover = File(dir.path);
      final backup = File('${dir.path}.file');
      if (await backup.exists()) {
        await leftover.delete();
      } else {
        await leftover.rename(backup.path);
      }
    }
  } catch (_) {}
  await dir.create(recursive: true);
}

Future<bool> probeCookieDirWritable(Directory dir) async {
  await prepareCookieDir(dir);
  final probe = File(
    '${dir.path}${Platform.pathSeparator}cookie_write_test',
  );
  await probe.writeAsBytes(const [0x6f, 0x6b]);
  var wrote = false;
  try {
    wrote = (await probe.readAsBytes()).isNotEmpty;
  } catch (_) {
    wrote = await probe.exists();
  }
  try {
    if (await probe.exists()) {
      await probe.delete();
    }
  } catch (_) {}
  return wrote;
}

Future<void> _copyIfMissing(Directory from, Directory to, String name) async {
  final source = File('${from.path}${Platform.pathSeparator}$name');
  if (!await source.exists()) {
    return;
  }
  final target = File('${to.path}${Platform.pathSeparator}$name');
  if (await target.exists() && await target.length() > 2) {
    return;
  }
  await to.create(recursive: true);
  await source.copy(target.path);
}
