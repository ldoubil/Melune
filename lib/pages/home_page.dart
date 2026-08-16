import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/skeleton.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/widgets/track_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.appName});

  final String appName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MeluneTrack> _rank = [];
  List<MeluneTrack> _featured = [];
  var _loading = true;
  var _loadGen = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final bili = BiliScope.of(context);
    final gen = ++_loadGen;
    setState(() {
      _loading = _rank.isEmpty && _featured.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _loadList(() => bili.musicRank()),
        _loadList(() => bili.newSongs()),
      ]);
      if (!mounted || gen != _loadGen) {
        return;
      }
      setState(() {
        _rank = results[0];
        _featured = results[1].isNotEmpty ? results[1] : results[0];
        _loading = false;
      });
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
      final wide = MediaQuery.sizeOf(context).width >= 760;
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.listPadding(0, 8, 0, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MeluneSkeleton(height: wide ? 240 : 210, radius: 28),
              ),
              const SizedBox(height: 26),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MeluneSkeleton(width: 128, height: 22, radius: 8),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    for (var i = 0; i < 8; i++)
                      const Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Center(
                              child: MeluneSkeleton(
                                width: 20,
                                height: 14,
                                radius: 4,
                              ),
                            ),
                          ),
                          Expanded(child: TrackTileSkeleton()),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final featured = albumsFromTracks(_featured).take(8).toList();
    final rank = _rank.take(12).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.listPadding(0, 8, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: tokens.colorSecondary),
                ),
              ),
            if (featured.isNotEmpty) _FeaturedCarousel(albums: featured),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionTitle(
                '全站音乐榜',
                onSeeAll: _rank.isEmpty
                    ? null
                    : () => BrowseScope.of(context).openAlbumList(
                        title: '全站音乐榜',
                        albums: albumsFromTracks(_rank),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            if (rank.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '暂时没有榜单',
                  style: TextStyle(color: tokens.colorBase),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    for (var i = 0; i < rank.length; i++)
                      _RankRow(index: i, track: rank[i]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.albums});

  final List<MeluneAlbum> albums;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = CarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) {
      return;
    }
    final delta = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent || !_controller.hasClients) {
        return;
      }
      final amount = resolved.scrollDelta.dy != 0
          ? resolved.scrollDelta.dy
          : resolved.scrollDelta.dx;
      final position = _controller.position;
      final target = (position.pixels + amount).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target != position.pixels) {
        position.pointerScroll(amount);
      }
      resolved.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    return SizedBox(
      height: wide ? 240 : 210,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: CarouselView.weighted(
          controller: _controller,
          flexWeights: wide ? const [6, 3, 1] : const [7, 2],
          itemSnapping: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: tokens.colorRaisedBg,
          shape: shape,
          onTap: (index) =>
              BrowseScope.of(context).openAlbum(widget.albums[index]),
          children: [
            for (final album in widget.albums) _CarouselCard(album: album),
          ],
        ),
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.album});

  final MeluneAlbum album;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TrackCover(
          url: album.coverUrl,
          width: double.infinity,
          height: double.infinity,
          radius: 0,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x99000000)],
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (album.subtitle.isNotEmpty)
                Text(
                  album.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.index, required this.track});

  final int index;
  final MeluneTrack track;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final top = index < 3;
    return TrackTile(
      key: Key('rank-row-${track.id}'),
      track: track,
      leading: SizedBox(
        width: 36,
        child: Text(
          '${index + 1}'.padLeft(2, '0'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: top ? tokens.colorBrand : tokens.colorSecondary,
          ),
        ),
      ),
      onTap: () =>
          BrowseScope.of(context).openAlbum(MeluneAlbum.fromTrack(track)),
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
