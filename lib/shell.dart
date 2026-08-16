import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melune/app.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/navigation.dart';
import 'package:melune/pages/discover_page.dart';
import 'package:melune/pages/favorites_page.dart';
import 'package:melune/pages/home_page.dart';
import 'package:melune/pages/now_playing_page.dart';
import 'package:melune/pages/search_page.dart';
import 'package:melune/pages/settings_page.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/settings/shortcuts.dart';
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
  var _searchOpen = false;
  var _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchNavKey = GlobalKey<ContentNavigatorState>();
  final _navKeys = List<GlobalKey<ContentNavigatorState>>.generate(
    4,
    (_) => GlobalKey<ContentNavigatorState>(),
  );
  RootBrowseController? _browse;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onShortcut);
  }

  bool get _interceptBack {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _browse = RootBrowse.maybeOf(context);
    _browse?.attach(_openArtistFromOverlay);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onShortcut);
    _browse?.attach(null);
    _searchController.dispose();
    super.dispose();
  }

  bool _onShortcut(KeyEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx != null &&
        (ctx.widget is EditableText ||
            ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
            ctx.findAncestorWidgetOfExactType<TextField>() != null)) {
      return false;
    }
    if (!mounted) {
      return false;
    }
    return MeluneShortcuts.handle(event, PlaybackScope.read(context));
  }

  void _openArtistFromOverlay(MeluneUpProfile profile) {
    PlaybackScope.read(context).closeNowPlaying();
    setState(() => _searchOpen = false);
    final index = _visibleIndex(MediaQuery.sizeOf(context).width >= 720);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _navKeys[index].currentState?.openArtist(profile);
    });
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
    if (_searchOpen) {
      if (_searchNavKey.currentState?.pop() == true) {
        return;
      }
      setState(() => _searchOpen = false);
      return;
    }
    if (_navKeys[_visibleIndex(MediaQuery.sizeOf(context).width >= 720)]
            .currentState
            ?.pop() ==
        true) {
      return;
    }
    await _moveToBackground();
  }

  Future<void> _moveToBackground() async {
    if (kIsWeb) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await const MethodChannel(
          'dev.melune.app',
        ).invokeMethod<void>('moveToBackground');
      } catch (_) {}
      return;
    }
  }

  void _submitSearch(String value) {
    final query = value.trim();
    setState(() {
      _searchQuery = query;
      _searchOpen = true;
    });
  }

  void _openLibraryAlbum(MeluneAlbum album) {
    final next =
        (_index == kMeluneFavoritesIndex || _index == kMeluneSettingsIndex)
        ? 0
        : _index;
    setState(() {
      _index = next;
      _searchOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKeys[next].currentState?.openAlbum(album);
    });
  }

  void _selectTab(int index) {
    setState(() {
      _index = index;
      _searchOpen = false;
    });
  }

  int _visibleIndex(bool wide) {
    if (wide && _index == kMeluneFavoritesIndex) {
      return 0;
    }
    return _index;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final tabIndex = _visibleIndex(wide);
    final pages = [
      ContentNavigator(
        key: _navKeys[0],
        child: HomePage(appName: widget.appName),
      ),
      ContentNavigator(key: _navKeys[1], child: const DiscoverPage()),
      ContentNavigator(
        key: _navKeys[2],
        child: wide ? const SizedBox.shrink() : const FavoritesPage(),
      ),
      ContentNavigator(
        key: _navKeys[3],
        child: SettingsPage(
          appName: widget.appName,
          greet: widget.greet,
          window: widget.window,
        ),
      ),
    ];
    final tabs = IndexedStack(index: tabIndex, children: pages);
    final search = ContentNavigator(
      key: _searchNavKey,
      child: SearchPage(
        query: _searchQuery,
        onClose: () => setState(() => _searchOpen = false),
      ),
    );
    final body = _searchOpen ? search : tabs;
    final showSidebar = wide && !_searchOpen;

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
                            if (showSidebar)
                              MeluneSideNav(
                                index: tabIndex,
                                onSelect: _selectTab,
                                onOpenAlbum: _openLibraryAlbum,
                              ),
                            ContentFrame(wide: showSidebar, child: body),
                          ],
                        )
                      : Column(
                          children: [
                            ContentFrame(wide: false, child: body),
                            MeluneMobileNav(
                              index: _index,
                              onSelect: _selectTab,
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
