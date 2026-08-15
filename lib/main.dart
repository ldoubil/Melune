import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/app.dart';
import 'package:melune/bili/rust_bili_client.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/src/rust/api/simple.dart';
import 'package:melune/src/rust/frb_generated.dart';
import 'package:melune/window/desktop_window.dart';
import 'package:melune/window/window_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    JustAudioMediaKit.ensureInitialized();
  } catch (_) {
    // 测试或缺少 native 库时仍启动界面。
  }

  var window = WindowController();
  if (isDesktopWindow) {
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setTitle('Melune · 洛音');
    window = DesktopWindowController();
  }

  await RustLib.init();
  final bili = RustBiliClient();
  final support = await getApplicationSupportDirectory();
  await bili.init(support.uri.resolve('bili/').toFilePath());
  final accounts = AccountStore(bili: bili);
  await accounts.refresh();
  final playback = PlaybackStore(bili: bili);

  runApp(
    MeluneApp(
      appName: appName(),
      greet: greet,
      window: window,
      bili: bili,
      accounts: accounts,
      playback: playback,
    ),
  );
}
