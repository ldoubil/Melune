import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/pages/album_list_page.dart';
import 'package:melune/pages/album_page.dart';

class BrowseScope extends InheritedWidget {
  const BrowseScope({
    super.key,
    required this.openAlbum,
    required this.openAlbumList,
    required super.child,
  });

  final void Function(MeluneAlbum album) openAlbum;
  final void Function({required String title, required List<MeluneAlbum> albums})
      openAlbumList;

  static BrowseScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BrowseScope>();
    assert(scope != null, 'BrowseScope not found');
    return scope!;
  }

  static BrowseScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BrowseScope>();
  }

  @override
  bool updateShouldNotify(BrowseScope oldWidget) => false;
}

class ContentNavigator extends StatefulWidget {
  const ContentNavigator({super.key, required this.child});

  final Widget child;

  @override
  ContentNavigatorState createState() => ContentNavigatorState();
}

class ContentNavigatorState extends State<ContentNavigator> {
  final List<_BrowseEntry> _stack = [];
  var _seq = 0;

  bool get canPop => _stack.isNotEmpty;

  bool pop() {
    if (_stack.isEmpty) {
      return false;
    }
    setState(() {
      _stack.removeLast();
    });
    return true;
  }

  void _openAlbum(MeluneAlbum album) {
    setState(() {
      _stack.add(
        _BrowseEntry.album(
          album,
          ValueKey('album-${_seq++}-${album.id}'),
        ),
      );
    });
  }

  void _openAlbumList({
    required String title,
    required List<MeluneAlbum> albums,
  }) {
    setState(() {
      _stack.add(
        _BrowseEntry.list(
          title,
          albums,
          ValueKey('album-list-${_seq++}-$title'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BrowseScope(
      openAlbum: _openAlbum,
      openAlbumList: _openAlbumList,
      child: NotificationListener<NavigationNotification>(
        onNotification: (_) => true,
        child: Navigator(
          pages: [
            MaterialPage<void>(
              key: const ValueKey('content-root'),
              child: widget.child,
            ),
            for (final entry in _stack) entry.page(),
          ],
          onDidRemovePage: (page) {
            if (page.key == const ValueKey('content-root')) {
              return;
            }
            final index = _stack.indexWhere((entry) => entry.key == page.key);
            if (index < 0) {
              return;
            }
            setState(() {
              _stack.removeAt(index);
            });
          },
        ),
      ),
    );
  }
}

class _BrowseEntry {
  const _BrowseEntry.album(this.album, this.key)
      : title = '',
        albums = const [];

  const _BrowseEntry.list(this.title, this.albums, this.key) : album = null;

  final LocalKey key;
  final MeluneAlbum? album;
  final String title;
  final List<MeluneAlbum> albums;

  Page<void> page() {
    if (album != null) {
      return MaterialPage<void>(
        key: key,
        child: AlbumPage(album: album!),
      );
    }
    return MaterialPage<void>(
      key: key,
      child: AlbumListPage(title: title, albums: albums),
    );
  }
}
