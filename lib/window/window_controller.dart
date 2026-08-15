import 'package:flutter/foundation.dart';

bool get isDesktopWindow {
  if (kIsWeb) {
    return false;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

class WindowController extends ChangeNotifier {
  bool get enabled => false;

  bool get isMaximized => false;

  Future<void> minimize() async {}

  Future<void> toggleMaximize() async {}

  Future<void> close() async {}

  Future<void> startDragging() async {}
}
