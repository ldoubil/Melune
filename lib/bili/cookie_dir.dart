import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 选出应用私有、原生层也能写的目录，避免 Uri.resolve 把路径解析到沙箱外。
///
/// 永远不要落到临时目录：系统会清缓存，登录态就会时有时无。
Future<String> resolveBiliCookieDir() async {
  final candidates = <Directory>[];
  try {
    candidates.add(
      Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}bili',
      ),
    );
  } catch (_) {}
  try {
    candidates.add(
      Directory(
        '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}bili',
      ),
    );
  } catch (_) {}

  final errors = <String>[];
  Directory? writable;
  Directory? withCookies;
  for (final dir in candidates) {
    try {
      await dir.create(recursive: true);
      final probe = File('${dir.path}${Platform.pathSeparator}.write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
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

  final chosen = writable ?? withCookies;
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

Future<void> _copyIfMissing(Directory from, Directory to, String name) async {
  final source = File('${from.path}${Platform.pathSeparator}$name');
  if (!await source.exists()) {
    return;
  }
  final target = File('${to.path}${Platform.pathSeparator}$name');
  if (await target.exists() && await target.length() > 2) {
    return;
  }
  await source.copy(target.path);
}
