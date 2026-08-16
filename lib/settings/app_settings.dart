import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:melune/settings/http_proxy.dart';
import 'package:melune/settings/launch_at_startup.dart';
import 'package:melune/window/desktop_lyric.dart';

enum MeluneThemeChoice { system, dark, light }

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  String? persistDir;
  var closeToTray = true;
  var launchAtStartup = false;
  var startMinimized = false;
  var preferredQualityId = 0;
  var playbackModeIndex = 0;
  var volume = 0.8;
  var resumeAutoplay = false;
  var desktopLyricOnStart = false;
  var lyricEffect = DesktopLyricEffect.reel;
  var lyricLocked = false;
  var lyricOpacity = 1.0;
  var offlineMaxMb = 4096;
  var offlineDir = '';
  var themeChoice = MeluneThemeChoice.system;
  var eqEnabled = false;
  List<double> eqGains = List<double>.filled(10, 0);
  var proxyEnabled = false;
  var proxyHost = '127.0.0.1';
  var proxyPort = 7890;
  var skipSilence = false;
  Map<String, String> shortcutOverrides = {};

  ThemeMode get themeMode => switch (themeChoice) {
    MeluneThemeChoice.system => ThemeMode.system,
    MeluneThemeChoice.dark => ThemeMode.dark,
    MeluneThemeChoice.light => ThemeMode.light,
  };

  String shortcutOf(String id, String fallback) {
    return shortcutOverrides[id] ?? fallback;
  }

  Future<void> restore(String? dir) async {
    persistDir = dir;
    final file = _file;
    if (file == null || !file.existsSync()) {
      installHttpProxyOverrides();
      writeProxyStamp();
      return;
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) {
        installHttpProxyOverrides();
        writeProxyStamp();
        return;
      }
      closeToTray = raw['closeToTray'] != false;
      launchAtStartup = raw['launchAtStartup'] == true;
      startMinimized = raw['startMinimized'] == true;
      preferredQualityId = (raw['preferredQualityId'] as num?)?.toInt() ?? 0;
      playbackModeIndex = (raw['playbackModeIndex'] as num?)?.toInt() ?? 0;
      volume = ((raw['volume'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0);
      resumeAutoplay = raw['resumeAutoplay'] == true;
      desktopLyricOnStart = raw['desktopLyricOnStart'] == true;
      lyricEffect = DesktopLyricEffect.parse(raw['lyricEffect']);
      lyricLocked = raw['lyricLocked'] == true;
      lyricOpacity = ((raw['lyricOpacity'] as num?)?.toDouble() ?? 1.0).clamp(
        0.2,
        1.0,
      );
      offlineMaxMb = (raw['offlineMaxMb'] as num?)?.toInt() ?? 4096;
      offlineDir = raw['offlineDir'] as String? ?? '';
      themeChoice = MeluneThemeChoice.values.firstWhere(
        (item) => item.name == raw['themeChoice'],
        orElse: () => MeluneThemeChoice.system,
      );
      eqEnabled = raw['eqEnabled'] == true;
      skipSilence = raw['skipSilence'] == true;
      proxyEnabled = raw['proxyEnabled'] == true;
      proxyHost = raw['proxyHost'] as String? ?? '127.0.0.1';
      proxyPort = (raw['proxyPort'] as num?)?.toInt() ?? 7890;
      final gains = raw['eqGains'];
      if (gains is List) {
        eqGains = [
          for (var i = 0; i < 10; i++)
            i < gains.length ? ((gains[i] as num?)?.toDouble() ?? 0) : 0,
        ];
      }
      final shortcuts = raw['shortcuts'];
      if (shortcuts is Map) {
        shortcutOverrides = {
          for (final entry in shortcuts.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
        };
      }
      notifyListeners();
    } catch (_) {}
    installHttpProxyOverrides();
    writeProxyStamp();
  }

  void setCloseToTray(bool value) => _set(() => closeToTray = value);

  Future<void> setLaunchAtStartup(bool value) async {
    launchAtStartup = value;
    notifyListeners();
    _persist();
    await syncLaunchAtStartup(enabled: value);
  }

  void setStartMinimized(bool value) => _set(() => startMinimized = value);

  void setPreferredQualityId(int value) =>
      _set(() => preferredQualityId = value);

  void setPlaybackModeIndex(int value) => _set(() => playbackModeIndex = value);

  void setVolume(double value) => _set(() => volume = value.clamp(0.0, 1.0));

  void setResumeAutoplay(bool value) => _set(() => resumeAutoplay = value);

  void setDesktopLyricOnStart(bool value) =>
      _set(() => desktopLyricOnStart = value);

  void setLyricEffect(DesktopLyricEffect value) =>
      _set(() => lyricEffect = value);

  void setLyricLocked(bool value) => _set(() => lyricLocked = value);

  void setLyricOpacity(double value) =>
      _set(() => lyricOpacity = value.clamp(0.2, 1.0));

  void setOfflineMaxMb(int value) => _set(() => offlineMaxMb = value);

  void setOfflineDir(String value) => _set(() => offlineDir = value.trim());

  void setThemeChoice(MeluneThemeChoice value) =>
      _set(() => themeChoice = value);

  void setEqEnabled(bool value) => _set(() => eqEnabled = value);

  void setEqGains(List<double> value) {
    eqGains = [
      for (var i = 0; i < 10; i++)
        i < value.length ? value[i].clamp(-12.0, 12.0) : 0,
    ];
    notifyListeners();
    _persist();
  }

  void setEqBand(int index, double gain) {
    if (index < 0 || index >= eqGains.length) {
      return;
    }
    eqGains = List<double>.from(eqGains)..[index] = gain.clamp(-12.0, 12.0);
    notifyListeners();
  }

  void setProxyEnabled(bool value) {
    proxyEnabled = value;
    notifyListeners();
    _persist();
    writeProxyStamp();
  }

  void setProxyHost(String value) {
    proxyHost = value.trim();
    notifyListeners();
    _persist();
    writeProxyStamp();
  }

  void setProxyPort(int value) {
    proxyPort = value.clamp(1, 65535);
    notifyListeners();
    _persist();
    writeProxyStamp();
  }

  void setSkipSilence(bool value) => _set(() => skipSilence = value);

  void setShortcut(String id, String binding) {
    final trimmed = binding.trim();
    if (trimmed.isEmpty) {
      shortcutOverrides.remove(id);
    } else {
      shortcutOverrides[id] = trimmed;
    }
    notifyListeners();
    _persist();
  }

  void resetShortcuts() {
    shortcutOverrides.clear();
    notifyListeners();
    _persist();
  }

  void writeProxyStamp() {
    updateHttpProxyConfig(
      enabled: proxyEnabled,
      host: proxyHost,
      port: proxyPort,
    );
    final base = persistDir;
    if (base == null || base.isEmpty) {
      return;
    }
    final file = File('$base${Platform.pathSeparator}http_proxy');
    try {
      if (!proxyEnabled || proxyHost.isEmpty) {
        if (file.existsSync()) {
          file.deleteSync();
        }
        return;
      }
      file.writeAsStringSync('http://$proxyHost:$proxyPort', flush: true);
    } catch (_) {}
  }

  String get defaultOfflineDir {
    final base = persistDir;
    if (base == null || base.isEmpty) {
      return '${Directory.systemTemp.path}${Platform.pathSeparator}melune_offline';
    }
    return '$base${Platform.pathSeparator}offline';
  }

  String get effectiveOfflineDir {
    final custom = offlineDir.trim();
    return custom.isEmpty ? defaultOfflineDir : custom;
  }

  void _set(VoidCallback mutate) {
    mutate();
    notifyListeners();
    _persist();
  }

  void _persist() {
    final file = _file;
    if (file == null) {
      return;
    }
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_toJson()), flush: true);
    } catch (_) {}
  }

  Map<String, Object?> _toJson() {
    return {
      'closeToTray': closeToTray,
      'launchAtStartup': launchAtStartup,
      'startMinimized': startMinimized,
      'preferredQualityId': preferredQualityId,
      'playbackModeIndex': playbackModeIndex,
      'volume': volume,
      'resumeAutoplay': resumeAutoplay,
      'desktopLyricOnStart': desktopLyricOnStart,
      'lyricEffect': lyricEffect.name,
      'lyricLocked': lyricLocked,
      'lyricOpacity': lyricOpacity,
      'offlineMaxMb': offlineMaxMb,
      'offlineDir': offlineDir,
      'themeChoice': themeChoice.name,
      'eqEnabled': eqEnabled,
      'eqGains': eqGains,
      'proxyEnabled': proxyEnabled,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
      'skipSilence': skipSilence,
      'shortcuts': shortcutOverrides,
    };
  }

  File? get _file {
    final base = persistDir;
    if (base == null || base.isEmpty) {
      return null;
    }
    return File('$base${Platform.pathSeparator}settings.json');
  }
}
