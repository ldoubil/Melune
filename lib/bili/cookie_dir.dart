import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 选出应用私有、原生层也能写的目录，避免 Uri.resolve 把路径解析到沙箱外。
Future<String> resolveBiliCookieDir() async {
  final roots = <Directory>[];
  try {
    roots.add(await getApplicationSupportDirectory());
  } catch (_) {}
  try {
    roots.add(await getApplicationDocumentsDirectory());
  } catch (_) {}
  try {
    roots.add(await getTemporaryDirectory());
  } catch (_) {}

  final errors = <String>[];
  for (final root in roots) {
    final dir = Directory('${root.path}${Platform.pathSeparator}bili');
    try {
      await dir.create(recursive: true);
      final probe = File('${dir.path}${Platform.pathSeparator}.write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return dir.path;
    } catch (err) {
      errors.add('${dir.path}: $err');
    }
  }
  throw Exception(
    errors.isEmpty ? '没有可用的应用目录' : '没有可写的 cookie 目录\n${errors.join('\n')}',
  );
}
