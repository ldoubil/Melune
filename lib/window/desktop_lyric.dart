import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/services.dart';
import 'package:melune/window/window_controller.dart';

const kDesktopLyricBusinessId = 'desktop_lyric';
const kDesktopLyricArguments = '{"businessId":"$kDesktopLyricBusinessId"}';
const kDesktopLyricDownChannel = 'melune/lyric/down';
const kDesktopLyricUpChannel = 'melune/lyric/up';

enum DesktopLyricEffect {
  reel,
  karaoke,
  glow,
  dual;

  String get label => switch (this) {
    DesktopLyricEffect.reel => '卷轴滚动',
    DesktopLyricEffect.karaoke => '卡拉OK',
    DesktopLyricEffect.glow => '霓虹呼吸',
    DesktopLyricEffect.dual => '双行渐显',
  };

  static DesktopLyricEffect parse(Object? raw) {
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) {
          return value;
        }
      }
    }
    if (raw is num) {
      final index = raw.toInt();
      if (index >= 0 && index < values.length) {
        return values[index];
      }
    }
    return DesktopLyricEffect.reel;
  }
}

class DesktopLyricSnapshot {
  const DesktopLyricSnapshot({
    this.visible = false,
    this.locked = true,
    this.liked = false,
    this.coverUrl = '',
    this.previous = '',
    this.current = '',
    this.next = '',
    this.title = '',
    this.effect = DesktopLyricEffect.reel,
    this.progress = 0,
    this.opacity = 1,
  });

  final bool visible;
  final bool locked;
  final bool liked;
  final String coverUrl;
  final String previous;
  final String current;
  final String next;
  final String title;
  final DesktopLyricEffect effect;
  final double progress;
  final double opacity;

  factory DesktopLyricSnapshot.fromMap(Map<String, dynamic> map) {
    return DesktopLyricSnapshot(
      visible: map['visible'] == true,
      locked: map['locked'] == true,
      liked: map['liked'] == true,
      coverUrl: map['coverUrl'] as String? ?? '',
      previous: map['previous'] as String? ?? '',
      current: map['current'] as String? ?? '',
      next: map['next'] as String? ?? '',
      title: map['title'] as String? ?? '',
      effect: DesktopLyricEffect.parse(map['effect']),
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      opacity: ((map['opacity'] as num?)?.toDouble() ?? 1).clamp(0.2, 1.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visible': visible,
      'locked': locked,
      'liked': liked,
      'coverUrl': coverUrl,
      'previous': previous,
      'current': current,
      'next': next,
      'title': title,
      'effect': effect.name,
      'progress': progress,
      'opacity': opacity,
    };
  }
}

const _down = dmw.WindowMethodChannel(
  kDesktopLyricDownChannel,
  mode: dmw.ChannelMode.unidirectional,
);
const _up = dmw.WindowMethodChannel(
  kDesktopLyricUpChannel,
  mode: dmw.ChannelMode.unidirectional,
);

final class DesktopLyricHost {
  DesktopLyricHost._();

  static final DesktopLyricHost instance = DesktopLyricHost._();

  dmw.WindowController? _controller;
  Future<dmw.WindowController>? _creating;
  bool _attached = false;

  void attach({
    required VoidCallback onClosed,
    required VoidCallback onToggleLike,
    required VoidCallback onToggleLock,
    required VoidCallback onCycleEffect,
  }) {
    if (!isDesktopWindow || _attached) {
      return;
    }
    _attached = true;
    unawaited(() async {
      try {
        await _up.setMethodCallHandler((call) async {
          switch (call.method) {
            case 'closed':
              onClosed();
              return null;
            case 'toggleLike':
              onToggleLike();
              return null;
            case 'toggleLock':
              onToggleLock();
              return null;
            case 'cycleEffect':
              onCycleEffect();
              return null;
            default:
              throw MissingPluginException(call.method);
          }
        });
      } catch (_) {}
    }());
    unawaited(preload());
  }

  Future<void> preload() async {
    if (!isDesktopWindow) {
      return;
    }
    try {
      await _ensure();
    } catch (_) {}
  }

  Future<void> push(DesktopLyricSnapshot snapshot) async {
    if (!isDesktopWindow) {
      return;
    }
    try {
      if (!snapshot.visible) {
        final existing = _controller;
        if (existing != null) {
          await _send(snapshot);
          await existing.hide();
        }
        return;
      }
      final controller = await _ensure();
      await _send(snapshot);
      await controller.show();
    } catch (_) {}
  }

  Future<dmw.WindowController> _ensure() async {
    final current = _controller;
    if (current != null) {
      return current;
    }
    final inflight = _creating;
    if (inflight != null) {
      return inflight;
    }
    final future = _create();
    _creating = future;
    try {
      final created = await future;
      _controller = created;
      return created;
    } finally {
      _creating = null;
    }
  }

  Future<dmw.WindowController> _create() async {
    final all = await dmw.WindowController.getAll();
    for (final controller in all) {
      if (controller.arguments.contains(kDesktopLyricBusinessId)) {
        return controller;
      }
    }
    return dmw.WindowController.create(
      const dmw.WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: kDesktopLyricArguments,
      ),
    );
  }

  Future<void> _send(DesktopLyricSnapshot snapshot) async {
    Object? lastError;
    for (var i = 0; i < 24; i++) {
      try {
        await _down.invokeMethod('state', snapshot.toMap());
        return;
      } catch (err) {
        lastError = err;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }
}

void attachDesktopLyricHost({
  required VoidCallback onClosed,
  required VoidCallback onToggleLike,
  required VoidCallback onToggleLock,
  required VoidCallback onCycleEffect,
}) {
  DesktopLyricHost.instance.attach(
    onClosed: onClosed,
    onToggleLike: onToggleLike,
    onToggleLock: onToggleLock,
    onCycleEffect: onCycleEffect,
  );
}

void syncDesktopLyric({
  required bool visible,
  required bool locked,
  required bool liked,
  required String coverUrl,
  required String previous,
  required String current,
  required String next,
  String title = '',
  DesktopLyricEffect effect = DesktopLyricEffect.reel,
  double progress = 0,
  double opacity = 1,
}) {
  unawaited(
    DesktopLyricHost.instance.push(
      DesktopLyricSnapshot(
        visible: visible,
        locked: locked,
        liked: liked,
        coverUrl: coverUrl,
        previous: previous,
        current: current,
        next: next,
        title: title,
        effect: effect,
        progress: progress,
        opacity: opacity,
      ),
    ),
  );
}
