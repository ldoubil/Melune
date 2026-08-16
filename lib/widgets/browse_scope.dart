import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/pages/offline_page.dart';
import 'package:melune/pages/album_list_page.dart';
import 'package:melune/pages/album_page.dart';
import 'package:melune/pages/artist_page.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';

class BrowseScope extends InheritedWidget {
  const BrowseScope({
    super.key,
    required this.openAlbum,
    required this.openAlbumList,
    required this.openArtist,
    required super.child,
  });

  final void Function(MeluneAlbum album) openAlbum;
  final void Function({
    required String title,
    required List<MeluneAlbum> albums,
  })
  openAlbumList;
  final void Function(MeluneUpProfile profile) openArtist;

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

void popContent(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || route.isFirst) {
    return;
  }
  Navigator.of(context).pop();
}

bool contentNavigatorHandlesSystemPop(PlaybackStore store) {
  if (store.nowPlayingOpen || store.playlistOpen) {
    return false;
  }
  if (kIsWeb) {
    return true;
  }
  // Android 系统返回会先问最内层 Navigator。歌单页若自己 pop，正在播放还在上面，
  // 看起来就要返回两次才关掉歌词。
  return defaultTargetPlatform != TargetPlatform.android;
}

void openArtistFromTrack(BuildContext context, MeluneTrack track) {
  if (track.upMid <= 0) {
    return;
  }
  final profile = MeluneUpProfile(mid: track.upMid, name: track.artist);
  final scoped = BrowseScope.maybeOf(context);
  if (scoped != null) {
    scoped.openArtist(profile);
    return;
  }
  RootBrowse.maybeOf(context)?.openArtist(profile);
}

class RootBrowseController {
  void Function(MeluneUpProfile profile)? _openArtist;

  void attach(void Function(MeluneUpProfile profile)? openArtist) {
    _openArtist = openArtist;
  }

  void openArtist(MeluneUpProfile profile) {
    _openArtist?.call(profile);
  }
}

class RootBrowse extends InheritedWidget {
  const RootBrowse({super.key, required this.controller, required super.child});

  final RootBrowseController controller;

  static RootBrowseController? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<RootBrowse>()?.controller;
  }

  @override
  bool updateShouldNotify(RootBrowse oldWidget) {
    return controller != oldWidget.controller;
  }
}

class RootBrowseScope extends StatefulWidget {
  const RootBrowseScope({super.key, required this.child});

  final Widget child;

  @override
  State<RootBrowseScope> createState() => _RootBrowseScopeState();
}

class _RootBrowseScopeState extends State<RootBrowseScope> {
  final _controller = RootBrowseController();

  @override
  Widget build(BuildContext context) {
    return RootBrowse(controller: _controller, child: widget.child);
  }
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

  void openAlbum(MeluneAlbum album) => _openAlbum(album);

  void openAlbumList({
    required String title,
    required List<MeluneAlbum> albums,
  }) => _openAlbumList(title: title, albums: albums);

  void openArtist(MeluneUpProfile profile) => _openArtist(profile);

  void _openAlbum(MeluneAlbum album) {
    setState(() {
      _stack.add(
        _BrowseEntry.album(album, ValueKey('album-${_seq++}-${album.id}')),
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

  void _openArtist(MeluneUpProfile profile) {
    if (profile.mid <= 0) {
      return;
    }
    setState(() {
      _stack.add(
        _BrowseEntry.artist(
          profile,
          ValueKey('artist-${_seq++}-${profile.mid}'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = PlaybackScope.read(context);
    return BrowseScope(
      openAlbum: _openAlbum,
      openAlbumList: _openAlbumList,
      openArtist: _openArtist,
      child: PlaybackSelect(
        player: player,
        selector: (store) => (store.nowPlayingOpen, store.playlistOpen),
        builder: (context, store) {
          return PopScope(
            canPop: contentNavigatorHandlesSystemPop(store),
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
                  final index = _stack.indexWhere(
                    (entry) => entry.key == page.key,
                  );
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
        },
      ),
    );
  }
}

class _BrowseEntry {
  const _BrowseEntry.album(this.album, this.key)
    : title = '',
      albums = const [],
      profile = null;

  const _BrowseEntry.list(this.title, this.albums, this.key)
    : album = null,
      profile = null;

  const _BrowseEntry.artist(this.profile, this.key)
    : album = null,
      title = '',
      albums = const [];

  final LocalKey key;
  final MeluneAlbum? album;
  final String title;
  final List<MeluneAlbum> albums;
  final MeluneUpProfile? profile;

  Page<void> page() {
    if (profile != null) {
      return MaterialPage<void>(
        key: key,
        child: ArtistPage(profile: profile!),
      );
    }
    if (album != null) {
      if (album!.id == 'offline') {
        return MaterialPage<void>(key: key, child: const OfflinePage());
      }
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
