import 'package:melune/player/media_handler.dart';

WindowsTaskbarMedia? bootstrapWindowsTaskbar() => null;

class WindowsTaskbarMedia implements NowPlayingBridge {
  @override
  void attach(MediaSessionHost host) {}

  @override
  void detach() {}

  @override
  void syncFrom(MediaSessionHost host, {bool force = false}) {}
}
