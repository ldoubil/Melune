import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/fake_bili_client.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/shell.dart';
import 'package:melune/theme/tokens.dart';
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
    return BiliScope(
      client: client,
      child: AccountScope(
        store: accounts ?? _defaultAccounts,
        child: PlaybackScope(
          store: playback ?? _defaultPlayback,
          child: MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            theme: buildMeluneTheme(MeluneTokens.light, Brightness.light),
            darkTheme: buildMeluneTheme(MeluneTokens.dark, Brightness.dark),
            builder: (context, child) {
              final app = child ?? const SizedBox.shrink();
              if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
                return app;
              }
              return ExcludeSemantics(child: app);
            },
            home: MeluneShell(
              appName: appName,
              greet: greet,
              window: window ?? _defaultWindow,
            ),
          ),
        ),
      ),
    );
  }
}
