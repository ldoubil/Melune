import 'package:flutter/material.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/skeleton.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/widgets/track_like_button.dart';

List<MeluneAlbum> libraryAlbums({
  required List<MeluneFavoriteFolder> folders,
  required List<MeluneTrack> recent,
  int offlineCount = 0,
}) {
  return [
    MeluneAlbum(
      id: 'offline',
      title: '离线缓存',
      subtitle: offlineCount > 0 ? '$offlineCount 首' : '本地歌曲',
      coverUrl: '',
    ),
    if (recent.isNotEmpty)
      MeluneAlbum.fromTracks(
        id: 'recent',
        title: '最近播放',
        subtitle: '${recent.length} 首',
        tracks: List.of(recent),
      ),
    for (final folder in folders) MeluneAlbum.fromFolder(folder),
  ];
}

class LibraryRail extends StatefulWidget {
  const LibraryRail({super.key, required this.onOpenAlbum});

  final void Function(MeluneAlbum album) onOpenAlbum;

  @override
  State<LibraryRail> createState() => _LibraryRailState();
}

class _LibraryRailState extends State<LibraryRail> {
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
    final player = PlaybackScope.read(context);
    return ListenableBuilder(
      listenable: Listenable.merge([player.offline, player.favorites]),
      builder: (context, _) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '收藏夹',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.colorSecondary,
                      ),
                    ),
                  ),
                  if (loggedIn)
                    IconButton(
                      key: const Key('library-create'),
                      tooltip: '新建收藏夹',
                      visualDensity: VisualDensity.compact,
                      onPressed: _createFolder,
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: tokens.colorBase,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.colorSecondary,
                        ),
                      ),
                    ),
                  for (final album in albums)
                    _LibraryTile(
                      album: album,
                      onTap: () => widget.onOpenAlbum(album),
                    ),
                  if (_loading && loggedIn)
                    for (var i = 0; i < 4; i++) const LibraryTileSkeleton(),
                  if (!loggedIn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Text(
                        '登录后显示收藏夹',
                        style: TextStyle(fontSize: 12, color: tokens.colorBase),
                      ),
                    ),
                ],
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

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.album, required this.onTap});

  final MeluneAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pinned = album.id == 'offline' || album.id == 'recent';
    final icon = album.id == 'offline'
        ? Icons.download_rounded
        : Icons.history_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('library-${album.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Row(
              children: [
                pinned
                    ? Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.colorButtonBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 18, color: tokens.colorBrand),
                      )
                    : TrackCover(url: album.coverUrl, size: 36, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.colorContrast,
                        ),
                      ),
                      Text(
                        album.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: tokens.colorBase),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
