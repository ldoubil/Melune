import 'dart:async';

import 'package:flutter/services.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/settings/app_settings.dart';

class MeluneShortcuts {
  MeluneShortcuts._();

  static var capturing = false;

  static const defaults = <String, String>{
    'playPause': 'Space',
    'next': 'Control+Arrow Right',
    'previous': 'Control+Arrow Left',
    'like': 'Control+L',
    'lyric': 'Control+D',
    'volumeUp': 'Control+Arrow Up',
    'volumeDown': 'Control+Arrow Down',
    'seekForward': 'Arrow Right',
    'seekBack': 'Arrow Left',
  };

  static const labels = <String, String>{
    'playPause': '播放 / 暂停',
    'next': '下一首',
    'previous': '上一首',
    'like': '点心收藏',
    'lyric': '桌面歌词',
    'volumeUp': '音量加',
    'volumeDown': '音量减',
    'seekForward': '快进 5 秒',
    'seekBack': '快退 5 秒',
  };

  static const ids = [
    'playPause',
    'next',
    'previous',
    'like',
    'lyric',
    'volumeUp',
    'volumeDown',
    'seekForward',
    'seekBack',
  ];

  static String encode(KeyEvent event) {
    final parts = <String>[];
    final hw = HardwareKeyboard.instance;
    if (hw.isControlPressed) {
      parts.add('Control');
    }
    if (hw.isShiftPressed) {
      parts.add('Shift');
    }
    if (hw.isAltPressed) {
      parts.add('Alt');
    }
    if (hw.isMetaPressed) {
      parts.add('Meta');
    }
    parts.add(_labelOf(event.logicalKey));
    return parts.join('+');
  }

  static bool isModifierOnly(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.control ||
        event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.shift ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        event.logicalKey == LogicalKeyboardKey.alt ||
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight ||
        event.logicalKey == LogicalKeyboardKey.meta ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight;
  }

  static bool handle(KeyEvent event, PlaybackStore player) {
    if (capturing) {
      return false;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (isModifierOnly(event)) {
      return false;
    }
    final settings = AppSettings.instance;
    for (final id in ids) {
      final spec = _Spec.parse(settings.shortcutOf(id, defaults[id] ?? ''));
      if (spec == null || !spec.matches(event)) {
        continue;
      }
      if (event is KeyRepeatEvent && id != 'volumeUp' && id != 'volumeDown') {
        return false;
      }
      _run(id, player);
      return true;
    }
    return false;
  }

  static void _run(String id, PlaybackStore player) {
    switch (id) {
      case 'playPause':
        unawaited(player.togglePlay());
      case 'next':
        unawaited(player.next());
      case 'previous':
        unawaited(player.previous());
      case 'like':
        player.toggleLike();
      case 'lyric':
        player.toggleDesktopLyric();
      case 'volumeUp':
        unawaited(player.setVolume(player.volume + 0.05));
      case 'volumeDown':
        unawaited(player.setVolume(player.volume - 0.05));
      case 'seekForward':
        unawaited(player.seek(player.position + const Duration(seconds: 5)));
      case 'seekBack':
        final next = player.position - const Duration(seconds: 5);
        unawaited(
          player.seek(next < Duration.zero ? Duration.zero : next),
        );
    }
  }

  static String _labelOf(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) {
      return 'Space';
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return 'Arrow Left';
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return 'Arrow Right';
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return 'Arrow Up';
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return 'Arrow Down';
    }
    final label = key.keyLabel;
    if (label.isNotEmpty) {
      return label.length == 1 ? label.toUpperCase() : label;
    }
    return key.debugName ?? 'Key';
  }
}

class _Spec {
  const _Spec({
    required this.control,
    required this.shift,
    required this.alt,
    required this.meta,
    required this.key,
  });

  final bool control;
  final bool shift;
  final bool alt;
  final bool meta;
  final LogicalKeyboardKey key;

  static _Spec? parse(String raw) {
    final parts = raw
        .split('+')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    var control = false;
    var shift = false;
    var alt = false;
    var meta = false;
    LogicalKeyboardKey? key;
    for (final part in parts) {
      switch (part.toLowerCase()) {
        case 'control':
        case 'ctrl':
          control = true;
        case 'shift':
          shift = true;
        case 'alt':
          alt = true;
        case 'meta':
        case 'cmd':
        case 'win':
          meta = true;
        default:
          key = _keyOf(part);
      }
    }
    if (key == null) {
      return null;
    }
    return _Spec(
      control: control,
      shift: shift,
      alt: alt,
      meta: meta,
      key: key,
    );
  }

  bool matches(KeyEvent event) {
    final hw = HardwareKeyboard.instance;
    if (event.logicalKey != key) {
      return false;
    }
    return hw.isControlPressed == control &&
        hw.isShiftPressed == shift &&
        hw.isAltPressed == alt &&
        hw.isMetaPressed == meta;
  }

  static LogicalKeyboardKey? _keyOf(String raw) {
    switch (raw.toLowerCase()) {
      case 'space':
        return LogicalKeyboardKey.space;
      case 'arrow left':
        return LogicalKeyboardKey.arrowLeft;
      case 'arrow right':
        return LogicalKeyboardKey.arrowRight;
      case 'arrow up':
        return LogicalKeyboardKey.arrowUp;
      case 'arrow down':
        return LogicalKeyboardKey.arrowDown;
    }
    final wanted = raw.toUpperCase();
    const letters = {
      'A': LogicalKeyboardKey.keyA,
      'B': LogicalKeyboardKey.keyB,
      'C': LogicalKeyboardKey.keyC,
      'D': LogicalKeyboardKey.keyD,
      'E': LogicalKeyboardKey.keyE,
      'F': LogicalKeyboardKey.keyF,
      'G': LogicalKeyboardKey.keyG,
      'H': LogicalKeyboardKey.keyH,
      'I': LogicalKeyboardKey.keyI,
      'J': LogicalKeyboardKey.keyJ,
      'K': LogicalKeyboardKey.keyK,
      'L': LogicalKeyboardKey.keyL,
      'M': LogicalKeyboardKey.keyM,
      'N': LogicalKeyboardKey.keyN,
      'O': LogicalKeyboardKey.keyO,
      'P': LogicalKeyboardKey.keyP,
      'Q': LogicalKeyboardKey.keyQ,
      'R': LogicalKeyboardKey.keyR,
      'S': LogicalKeyboardKey.keyS,
      'T': LogicalKeyboardKey.keyT,
      'U': LogicalKeyboardKey.keyU,
      'V': LogicalKeyboardKey.keyV,
      'W': LogicalKeyboardKey.keyW,
      'X': LogicalKeyboardKey.keyX,
      'Y': LogicalKeyboardKey.keyY,
      'Z': LogicalKeyboardKey.keyZ,
    };
    return letters[wanted];
  }
}
