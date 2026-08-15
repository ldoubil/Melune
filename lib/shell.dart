import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melune/app.dart';
import 'package:melune/pages/favorites_page.dart';
import 'package:melune/pages/home_page.dart';
import 'package:melune/pages/now_playing_page.dart';
import 'package:melune/pages/search_page.dart';
import 'package:melune/pages/settings_page.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/content_frame.dart';
import 'package:melune/widgets/mobile_nav.dart';
import 'package:melune/widgets/side_nav.dart';
import 'package:melune/window/title_bar.dart';
import 'package:melune/window/window_controller.dart';

class MeluneShell extends StatefulWidget {
  const MeluneShell({
    super.key,
    required this.appName,
    required this.greet,
    required this.window,
  });

  final String appName;
  final GreetFn greet;
  final WindowController window;

  @override
  State<MeluneShell> createState() => _MeluneShellState();
}

class _MeluneShellState extends State<MeluneShell> {
  int _index = 0;
  var _searchQuery = '';
  final _searchController = TextEditingController();
  final _navKeys = List<GlobalKey<ContentNavigatorState>>.generate(
    4,
    (_) => GlobalKey<ContentNavigatorState>(),
  );

  bool get _interceptBack {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) {
      return;
    }
    final player = PlaybackScope.read(context);
    if (player.nowPlayingOpen) {
      player.closeNowPlaying();
      return;
    }
    if (player.playlistOpen) {
      player.closePlaylist();
      return;
    }
    if (_navKeys[_index].currentState?.pop() == true) {
      return;
    }
    await SystemNavigator.pop();
  }

  void _submitSearch(String value) {
    final query = value.trim();
    setState(() {
      _searchQuery = query;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pages = [
      ContentNavigator(
        key: _navKeys[0],
        child: HomePage(appName: widget.appName),
      ),
      ContentNavigator(
        key: _navKeys[1],
        child: SearchPage(query: _searchQuery),
      ),
      ContentNavigator(
        key: _navKeys[2],
        child: const FavoritesPage(),
      ),
      ContentNavigator(
        key: _navKeys[3],
        child: SettingsPage(appName: widget.appName, greet: widget.greet),
      ),
    ];
    final body = IndexedStack(index: _index, children: pages);

    return PopScope(
      canPop: !_interceptBack,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Scaffold(
        backgroundColor: tokens.colorRaisedBg,
        body: Stack(
          children: [
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: MeluneTitleBar(
                    window: widget.window,
                    appName: widget.appName,
                    showAccount: !wide,
                    searchController: _searchController,
                    onSearch: _submitSearch,
                  ),
                ),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            MeluneSideNav(
                              index: _index,
                              onSelect: (index) => setState(() => _index = index),
                            ),
                            ContentFrame(wide: true, child: body),
                          ],
                        )
                      : Column(
                          children: [
                            ContentFrame(wide: false, child: body),
                            MeluneMobileNav(
                              index: _index,
                              onSelect: (index) => setState(() => _index = index),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            const Positioned.fill(child: NowPlayingGate()),
          ],
        ),
      ),
    );
  }
}
