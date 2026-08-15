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
  return DesktopWindowController();
}

class DesktopWindowController extends WindowController with WindowListener {
  DesktopWindowController() {
    windowManager.addListener(this);
    _syncMaximized();
  }

  bool _maximized = false;

  @override
  bool get enabled => true;

  @override
  bool get isMaximized => _maximized;

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
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

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
