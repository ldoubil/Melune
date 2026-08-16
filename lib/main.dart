import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/app.dart';
import 'package:melune/bili/cookie_dir.dart';
import 'package:melune/bili/rust_bili_client.dart';
import 'package:melune/player/cover_cache.dart';
import 'package:melune/player/media_handler.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/player/windows_taskbar_media.dart'
    if (dart.library.html) 'package:melune/player/windows_taskbar_media_stub.dart';
import 'package:melune/player/equalizer.dart';
import 'package:melune/settings/app_settings.dart';
import 'package:melune/src/rust/api/simple.dart';
import 'package:melune/src/rust/frb_generated.dart';
import 'package:melune/window/app_tray.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:melune/window/desktop_lyric_app.dart';
import 'package:melune/window/desktop_window.dart';
import 'package:melune/window/window_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopWindow) {
    try {
      final engine = await dmw.WindowController.fromCurrentEngine();
      if (engine.arguments.contains(kDesktopLyricBusinessId)) {
        await runDesktopLyricWindow();
        return;
      }
    } catch (_) {
      // 主窗口或尚未接入多窗口插件时走正常启动。
    }
    unawaited(DesktopLyricHost.instance.preload());
  }
  runApp(const MeluneBootApp());

  NowPlayingBridge? media;
  try {
    JustAudioMediaKit.title = 'Melune';
    JustAudioMediaKit.ensureInitialized();
  } catch (_) {
    // 测试或缺少 native 库时仍启动界面。
  }
  try {
    media = await bootstrapMediaSession();
  } catch (err) {
    debugPrint('媒体会话初始化失败: $err');
  }

  try {
    final window = await bootstrapWindow();
    await RustLib.init();
    final cookieDir = await resolveBiliCookieDir();
    CoverCache.instance.attach(cookieDir);
    await AppSettings.instance.restore(cookieDir);
    final bili = RustBiliClient();
    final user = await bili.init(cookieDir);
    final accounts = AccountStore(bili: bili, initial: user);
    final playback = PlaybackStore(
      bili: bili,
      media: media,
      windows: bootstrapWindowsTaskbar(),
      persistDir: cookieDir,
    );
    await playback.restore();
    await MeluneEqualizer.applyFromSettings();
    await MeluneTray.instance.start(window: window, playback: playback);
    if (AppSettings.instance.startMinimized && window.enabled) {
      await window.hideToTray();
    }

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
  } catch (err, stack) {
    debugPrint('Melune 启动失败: $err\n$stack');
    runApp(MeluneErrorApp(error: err.toString()));
  }
}
