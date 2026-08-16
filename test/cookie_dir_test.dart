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
}
