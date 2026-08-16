import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:melune/settings/app_settings.dart';

class MeluneEqualizer {
  MeluneEqualizer._();

  static const bandsHz = [
    32,
    64,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  static const bandLabels = [
    '32',
    '64',
    '125',
    '250',
    '500',
    '1k',
    '2k',
    '4k',
    '8k',
    '16k',
  ];

  static const presets = <String, List<double>>{
    'flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'bass': [6, 5, 3, 1, 0, 0, 0, 0, 0, 0],
    'vocal': [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
    'electronic': [4, 3, 0, -1, 0, 1, 2, 4, 3, 2],
    'rock': [4, 3, 1, 0, -1, 1, 3, 4, 3, 2],
  };

  static const presetLabels = {
    'flat': '平直',
    'bass': '低音',
    'vocal': '人声',
    'electronic': '电子',
    'rock': '摇滚',
  };

  static String mpvFilter({required bool enabled, required List<double> gains}) {
    if (!enabled) {
      return '';
    }
    final parts = <String>[];
    for (var i = 0; i < bandsHz.length && i < gains.length; i++) {
      final gain = gains[i].clamp(-12.0, 12.0);
      if (gain.abs() < 0.05) {
        continue;
      }
      parts.add(
        'equalizer=f=${bandsHz[i]}:t=o:w=1:g=${gain.toStringAsFixed(1)}',
      );
    }
    if (parts.isEmpty) {
      return '';
    }
    return 'lavfi=[${parts.join(',')}]';
  }

  static Future<void> applyFromSettings({AndroidEqualizer? android}) async {
    final settings = AppSettings.instance;
    final filter = mpvFilter(enabled: settings.eqEnabled, gains: settings.eqGains);
    JustAudioMediaKit.applyAudioFilter(filter);
    if (android == null) {
      return;
    }
    try {
      await android.setEnabled(settings.eqEnabled);
      final parameters = await android.parameters;
      final bands = parameters.bands;
      final min = parameters.minDecibels;
      final max = parameters.maxDecibels;
      for (var i = 0; i < bands.length; i++) {
        final nearest = _nearestGain(
          settings.eqGains,
          bands[i].centerFrequency,
        );
        await bands[i].setGain(nearest.clamp(min, max));
      }
    } catch (_) {}
  }

  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static double _nearestGain(List<double> gains, double hz) {
    var best = 0;
    var bestDelta = double.infinity;
    for (var i = 0; i < bandsHz.length && i < gains.length; i++) {
      final delta = (bandsHz[i] - hz).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return gains[best];
  }
}
