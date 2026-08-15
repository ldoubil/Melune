import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';
import 'package:melune/widgets/browse_scope.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.appName});

  final String appName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MeluneTrack> _rank = [];
  List<MeluneTrack> _news = [];
  List<MeluneTrack> _latest = [];
  List<MeluneTrack> _rcmd = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final bili = BiliScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _loadList(() => bili.musicRank()),
        _loadList(() => bili.newSongs()),
        _loadList(() => bili.musicRegion()),
        _loadList(() => bili.musicRecommend()),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _rank = results[0];
        _news = results[1];
        _latest = results[2];
        _rcmd = results[3];
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

  Future<List<MeluneTrack>> _loadList(
    Future<List<MeluneTrack>> Function() load,
  ) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final albums = albumsFromTracks(_news);
    final recommended = albumsFromTracks(_rcmd);
    final fresh = albumsFromTracks(_latest);
    final discover = albumsFromTracks(_rank);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.listPadding(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: tokens.colorSecondary)),
              const SizedBox(height: 12),
            ],
            _SectionTitle(
              '新专',
              onSeeAll: albums.isEmpty
                  ? null
                  : () => BrowseScope.of(context).openAlbumList(
                        title: '新专',
                        albums: albums,
                      ),
            ),
            const SizedBox(height: 10),
            AlbumStrip(albums: albums, empty: '暂时没有新专'),
            const SizedBox(height: 26),
            const _SectionTitle('接着听'),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: PlaybackScope.of(context),
              builder: (context, _) {
                final player = PlaybackScope.of(context);
                return AlbumStrip(
                  albums: [
                    if (player.recentTracks.isNotEmpty)
                      MeluneAlbum.fromTracks(
                        id: 'recent',
                        title: '最近播放',
                        subtitle: '继续听',
                        tracks: player.recentTracks,
                      ),
                    if (player.likedTracks.isNotEmpty)
                      MeluneAlbum.fromTracks(
                        id: 'liked',
                        title: '我喜欢',
                        subtitle: '${player.likedTracks.length} 首',
                        tracks: player.likedTracks,
                      ),
                    if (_latest.isNotEmpty)
                      MeluneAlbum.fromTracks(
                        id: 'news',
                        title: '新歌速递',
                        subtitle: '刚刚上线',
                        tracks: _latest,
                      ),
                    if (_rank.isNotEmpty)
                      MeluneAlbum.fromTracks(
                        id: 'rank',
                        title: '音乐榜',
                        subtitle: '热门歌曲',
                        tracks: _rank,
                      ),
                  ],
                  empty: '还没有内容',
                );
              },
            ),
            const SizedBox(height: 26),
            _SectionTitle(
              '为你推荐',
              onSeeAll: recommended.isEmpty
                  ? null
                  : () => BrowseScope.of(context).openAlbumList(
                        title: '为你推荐',
                        albums: recommended,
                      ),
            ),
            const SizedBox(height: 10),
            AlbumStrip(albums: recommended, empty: '暂时没有推荐'),
            const SizedBox(height: 26),
            _SectionTitle(
              '新歌速递',
              onSeeAll: fresh.isEmpty
                  ? null
                  : () => BrowseScope.of(context).openAlbumList(
                        title: '新歌速递',
                        albums: fresh,
                      ),
            ),
            const SizedBox(height: 10),
            AlbumStrip(albums: fresh, empty: '暂时没有新歌'),
            const SizedBox(height: 26),
            _SectionTitle(
              '发现',
              onSeeAll: discover.isEmpty
                  ? null
                  : () => BrowseScope.of(context).openAlbumList(
                        title: '发现',
                        albums: discover,
                      ),
            ),
            const SizedBox(height: 10),
            AlbumStrip(albums: discover, empty: '暂时没有内容'),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: tokens.colorContrast,
      ),
    );
    if (onSeeAll == null) {
      return label;
    }
    return InkWell(
      key: Key('section-all-$title'),
      onTap: onSeeAll,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(child: label),
          Icon(Icons.chevron_right_rounded, color: tokens.colorBase),
        ],
      ),
    );
  }
}
