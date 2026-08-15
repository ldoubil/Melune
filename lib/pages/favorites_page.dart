import 'package:flutter/material.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  AccountStore? _accounts;
  List<MeluneFavoriteFolder> _folders = [];
  List<MeluneTrack> _history = [];
  var _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AccountScope.of(context);
    if (_accounts != store) {
      _accounts?.removeListener(_load);
      _accounts = store;
      _accounts!.addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _accounts?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final accounts = AccountScope.of(context);
    if (!accounts.isLoggedIn) {
      setState(() {
        _folders = [];
        _history = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bili = BiliScope.of(context);
      final folders = await bili.favoriteFolders();
      final history = await bili.history();
      final covers = await Future.wait(
        folders.map((folder) async {
          try {
            final page = await bili.favoriteTracks(folder.id);
            if (page.items.isEmpty) {
              return folder.coverUrl;
            }
            final first = page.items.first.coverUrl;
            return first.isNotEmpty ? first : folder.coverUrl;
          } catch (_) {
            return folder.coverUrl;
          }
        }),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _folders = [
          for (var i = 0; i < folders.length; i++)
            MeluneFavoriteFolder(
              id: folders[i].id,
              title: folders[i].title,
              mediaCount: folders[i].mediaCount,
              coverUrl: covers[i].isNotEmpty ? covers[i] : folders[i].coverUrl,
            ),
        ];
        _history = history.tracks;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  List<MeluneAlbum> _albums(List<MeluneTrack> liked) {
    return [
      if (liked.isNotEmpty)
        MeluneAlbum.fromTracks(
          id: 'liked',
          title: '我喜欢',
          subtitle: '收藏',
          tracks: liked,
        ),
      for (final folder in _folders) MeluneAlbum.fromFolder(folder),
      if (_history.isNotEmpty)
        MeluneAlbum.fromTracks(
          id: 'history',
          title: '最近播放',
          subtitle: '历史',
          tracks: _history,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final loggedIn = AccountScope.of(context).isLoggedIn;
    final player = PlaybackScope.of(context);

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final albums = _albums(player.likedTracks);

        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (albums.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.album_outlined, size: 48, color: tokens.colorBase),
                const SizedBox(height: 12),
                Text(
                  '还没有收藏',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.colorContrast,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loggedIn ? '喜欢的专辑会出现在这里' : '登录后会从 B 站同步收藏夹',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colorBase,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '专辑',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tokens.colorContrast,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: tokens.colorSecondary),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: AlbumGrid(
                  albums: albums,
                  padding: context.listPadding(16, 12, 16, 24),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
