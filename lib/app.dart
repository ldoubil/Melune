import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/fake_bili_client.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/settings/app_settings.dart';
import 'package:melune/shell.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/window/window_controller.dart';

typedef GreetFn = String Function({required String name});

class MeluneApp extends StatelessWidget {
  const MeluneApp({
    super.key,
    required this.appName,
    required this.greet,
    this.window,
    this.accounts,
    this.playback,
    this.bili,
  });

  final String appName;
  final GreetFn greet;
  final WindowController? window;
  final AccountStore? accounts;
  final PlaybackStore? playback;
  final BiliClient? bili;

  static final _defaultWindow = WindowController();
  static final _defaultBili = FakeBiliClient();
  static final _defaultAccounts = AccountStore(bili: _defaultBili);
  static final _defaultPlayback = PlaybackStore(bili: _defaultBili);

  @override
  Widget build(BuildContext context) {
    final client = bili ?? _defaultBili;
    final windowCtl = window ?? _defaultWindow;
    final accountStore = accounts ?? _defaultAccounts;
    final playbackStore =
        playback ??
        (identical(client, _defaultBili)
            ? _defaultPlayback
            : PlaybackStore(bili: client));
    return BiliScope(
      client: client,
      child: AccountScope(
        store: accountStore,
        child: PlaybackScope(
          store: playbackStore,
          child: RootBrowseScope(
            child: ListenableBuilder(
              listenable: AppSettings.instance,
              child: MeluneShell(
                appName: appName,
                greet: greet,
                window: windowCtl,
              ),
              builder: (context, child) {
                return MaterialApp(
                  title: appName,
                  debugShowCheckedModeBanner: false,
                  theme: buildMeluneTheme(MeluneTokens.light, Brightness.light),
                  darkTheme: buildMeluneTheme(
                    MeluneTokens.dark,
                    Brightness.dark,
                  ),
                  themeMode: AppSettings.instance.themeMode,
                  builder: (context, appChild) {
                    final app = appChild ?? const SizedBox.shrink();
                    if (kIsWeb ||
                        defaultTargetPlatform != TargetPlatform.windows) {
                      return app;
                    }
                    return ExcludeSemantics(child: app);
                  },
                  home: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MeluneBootApp extends StatelessWidget {
  const MeluneBootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = MeluneTokens.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMeluneTheme(tokens, Brightness.dark),
      home: Scaffold(
        backgroundColor: tokens.colorBg,
        body: Center(
          child: CircularProgressIndicator(color: tokens.colorBrand),
        ),
      ),
    );
  }
}

class MeluneErrorApp extends StatelessWidget {
  const MeluneErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = MeluneTokens.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMeluneTheme(tokens, Brightness.dark),
      home: Scaffold(
        backgroundColor: tokens.colorBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              '启动失败\n\n$error',
              style: TextStyle(color: tokens.colorContrast, height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}
