import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:melune/settings/app_settings.dart';
import 'package:melune/window/window_controller.dart';
import 'package:window_manager/window_manager.dart';

Future<WindowController> bootstrapWindow() async {
  if (!isDesktopWindow) {
    return WindowController();
  }
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setTitle('Melune · 洛音');
  await windowManager.setPreventClose(true);
  try {
    await windowManager.setIcon(
      defaultTargetPlatform == TargetPlatform.windows
          ? 'assets/tray/app_icon.ico'
          : 'assets/icon/app_icon.png',
    );
  } catch (_) {}
  return DesktopWindowController();
}

class DesktopWindowController extends WindowController with WindowListener {
  DesktopWindowController() {
    windowManager.addListener(this);
    _syncMaximized();
  }

  bool _maximized = false;
  var _hiddenToTray = false;
  var _quitting = false;

  @override
  bool get enabled => true;

  @override
  bool get isMaximized => _maximized;

  @override
  bool get hiddenToTray => _hiddenToTray;

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() async {
    if (AppSettings.instance.closeToTray) {
      await hideToTray();
      return;
    }
    await quit();
  }

  @override
  Future<void> hideToTray() async {
    if (_quitting) {
      return;
    }
    _hiddenToTray = true;
    notifyListeners();
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  @override
  Future<void> showFromTray() async {
    _hiddenToTray = false;
    notifyListeners();
    try {
      await windowManager.setSkipTaskbar(false);
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  @override
  Future<void> quit() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  void onWindowClose() {
    if (_quitting) {
      return;
    }
    if (AppSettings.instance.closeToTray) {
      unawaited(hideToTray());
      return;
    }
    unawaited(quit());
  }

  @override
  void onWindowMaximize() {
    _maximized = true;
    notifyListeners();
  }

  @override
  void onWindowUnmaximize() {
    _maximized = false;
    notifyListeners();
  }

  @override
  void onWindowRestore() {
    _syncMaximized();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (_maximized != maximized) {
      _maximized = maximized;
      notifyListeners();
    }
  }
}
