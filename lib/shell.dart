import 'package:flutter/material.dart';
import 'package:melune/app.dart';
import 'package:melune/pages/favorites_page.dart';
import 'package:melune/pages/home_page.dart';
import 'package:melune/pages/search_page.dart';
import 'package:melune/pages/settings_page.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      ContentNavigator(child: HomePage(appName: widget.appName)),
      ContentNavigator(child: SearchPage(query: _searchQuery)),
      const ContentNavigator(child: FavoritesPage()),
      ContentNavigator(
        child: SettingsPage(appName: widget.appName, greet: widget.greet),
      ),
    ];
    final body = IndexedStack(index: _index, children: pages);

    return Scaffold(
      backgroundColor: tokens.colorRaisedBg,
      appBar: MeluneTitleBar(
        window: widget.window,
        appName: widget.appName,
        showAccount: !wide,
        searchController: _searchController,
        onSearch: _submitSearch,
      ),
      body: wide
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
    );
  }
}
