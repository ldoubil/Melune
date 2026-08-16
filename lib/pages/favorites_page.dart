import 'package:flutter/material.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';
import 'package:melune/widgets/library_rail.dart';
import 'package:melune/widgets/track_like_button.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  AccountStore? _accounts;
  var _loading = false;
  var _loadGen = 0;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AccountScope.of(context);
    if (_accounts != store) {
      _accounts?.removeListener(_onAccount);
      _accounts = store;
      _accounts!.addListener(_onAccount);
      _load();
    }
  }

  @override
  void dispose() {
    _accounts?.removeListener(_onAccount);
    super.dispose();
  }

  void _onAccount() {
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final accounts = AccountScope.of(context);
    final favorites = PlaybackScope.read(context).favorites;
    if (!accounts.isLoggedIn) {
      favorites.clear();
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    final gen = ++_loadGen;
    setState(() {
      _loading = favorites.folders.isEmpty;
      _error = null;
    });
    try {
      await favorites.ensure(force: force);
      if (!mounted || gen != _loadGen) {
        return;
      }
      setState(() => _loading = false);
    } catch (err) {
      if (!mounted || gen != _loadGen) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _createFolder() async {
    final player = PlaybackScope.read(context);
    final created = await promptCreateMeluneFolder(
      context: context,
      player: player,
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final loggedIn = AccountScope.of(context).isLoggedIn;

    return ListenableBuilder(
      listenable: Listenable.merge([
        PlaybackScope.read(context).offline,
        PlaybackScope.read(context).favorites,
      ]),
      builder: (context, _) {
        final player = PlaybackScope.read(context);
        return PlaybackSelect(
          player: player,
          selector: (store) => (
            store.recentTracks.length,
            store.recentTracks.isEmpty ? '' : store.recentTracks.first.id,
          ),
          builder: (context, store) {
            final albums = libraryAlbums(
              folders: store.favorites.folders,
              recent: store.recentTracks,
              offlineCount: store.offline.cachedCount,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '歌单',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: tokens.colorContrast,
                      ),
                    ),
                  ),
                  if (loggedIn)
                    IconButton(
                      key: const Key('favorites-create'),
                      tooltip: '新建收藏夹',
                      onPressed: _createFolder,
                      icon: Icon(
                        Icons.create_new_folder_outlined,
                        color: tokens.colorBase,
                      ),
                    ),
                ],
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
            if (_loading && loggedIn)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: AlbumGrid(
                    albums: albums,
                    padding: context.listPadding(16, 12, 16, 24),
                    skeletonCount: 6,
                  ),
                ),
              )
            else if (albums.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 48,
                        color: tokens.colorBase,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '还没有收藏',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: tokens.colorContrast),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loggedIn
                            ? '点心会收到 Melune_默认收藏，长按心可选其它夹子'
                            : '登录后会自动创建 Melune 收藏夹',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.colorBase,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(force: true),
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
      },
    );
  }
}
