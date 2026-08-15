import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/services.dart';
import 'package:melune/window/window_controller.dart';

const kDesktopLyricBusinessId = 'desktop_lyric';
const kDesktopLyricArguments = '{"businessId":"$kDesktopLyricBusinessId"}';
const kDesktopLyricDownChannel = 'melune/lyric/down';
const kDesktopLyricUpChannel = 'melune/lyric/up';

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
  });

  final bool visible;
  final bool locked;
  final bool liked;
  final String coverUrl;
  final String previous;
  final String current;
  final String next;
  final String title;

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
}) {
  DesktopLyricHost.instance.attach(
    onClosed: onClosed,
    onToggleLike: onToggleLike,
    onToggleLock: onToggleLock,
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
      ),
    ),
  );
}
