import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melune/bili/cookie_dir.dart';

void main() {
  test('writable probe succeeds even if cleanup cannot delete', () async {
    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}melune_cookie_probe_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    expect(await probeCookieDirWritable(dir), isTrue);
    expect(await dir.exists(), isTrue);
  });

  test('writable probe recovers when the path is an existing file', () async {
    final dir = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}melune_cookie_file_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      final leftover = File('${dir.path}.file');
      if (await leftover.exists()) {
        await leftover.delete();
      }
      if (await FileSystemEntity.isDirectory(dir.path)) {
        await dir.delete(recursive: true);
      } else if (await File(dir.path).exists()) {
        await File(dir.path).delete();
      }
    });
    await File(dir.path).writeAsString('not a directory');
    expect(await probeCookieDirWritable(dir), isTrue);
    expect(await FileSystemEntity.isDirectory(dir.path), isTrue);
  });
}
