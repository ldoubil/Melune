import 'dart:io';

import 'package:flutter/foundation.dart';

Future<void> syncLaunchAtStartup({required bool enabled}) async {
  if (kIsWeb) {
    return;
  }
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        await _syncWindows(enabled);
      case TargetPlatform.linux:
        await _syncLinux(enabled);
      case TargetPlatform.macOS:
        await _syncMac(enabled);
      default:
        return;
    }
  } catch (_) {}
}

Future<void> _syncWindows(bool enabled) async {
  const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  if (!enabled) {
    await Process.run('reg', ['delete', key, '/v', 'Melune', '/f']);
    return;
  }
  final exe = Platform.resolvedExecutable;
  await Process.run('reg', [
    'add',
    key,
    '/v',
    'Melune',
    '/t',
    'REG_SZ',
    '/d',
    exe,
    '/f',
  ]);
}

Future<void> _syncLinux(bool enabled) async {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    return;
  }
  final file = File('$home/.config/autostart/melune.desktop');
  if (!enabled) {
    if (file.existsSync()) {
      await file.delete();
    }
    return;
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=Melune\n'
    'Exec=${Platform.resolvedExecutable}\n'
    'X-GNOME-Autostart-enabled=true\n',
    flush: true,
  );
}

Future<void> _syncMac(bool enabled) async {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    return;
  }
  final file = File('$home/Library/LaunchAgents/app.melune.startup.plist');
  if (!enabled) {
    if (file.existsSync()) {
      await Process.run('launchctl', ['unload', file.path]);
      await file.delete();
    }
    return;
  }
  await file.parent.create(recursive: true);
  final exe = Platform.resolvedExecutable
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;');
  await file.writeAsString(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0"><dict>'
    '<key>Label</key><string>app.melune.startup</string>'
    '<key>ProgramArguments</key><array><string>$exe</string></array>'
    '<key>RunAtLoad</key><true/>'
    '</dict></plist>\n',
    flush: true,
  );
  await Process.run('launchctl', ['load', file.path]);
}
