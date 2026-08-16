import 'dart:async';

import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/skeleton.dart';
import 'package:melune/widgets/track_cover.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<MeluneTrack> _zone = [];
  var _zoneId = 0;
  var _zonePage = 1;
  var _zoneHasMore = true;
  var _loading = true;
  var _loadingMore = false;
  var _gen = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadZone(0, force: true),
    );
  }

  Future<void> _loadZone(int cateId, {bool force = false}) async {
    if (!force && cateId == _zoneId && _zone.isNotEmpty) {
      return;
    }
    final bili = BiliScope.of(context);
    final gen = ++_gen;
    setState(() {
      _zoneId = cateId;
      _zone = [];
      _zonePage = 1;
      _zoneHasMore = true;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final tracks = await bili.musicZone(cateId: cateId, page: 1);
      if (!mounted || gen != _gen) {
        return;
      }
      setState(() {
        _zone = tracks;
        _zoneHasMore = tracks.isNotEmpty;
        _loading = false;
      });
    } catch (err) {
      if (!mounted || gen != _gen) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter < 720) {
      unawaited(_loadMore());
    }
    return false;
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_zoneHasMore || _zone.isEmpty) {
      return;
    }
    final bili = BiliScope.of(context);
    final gen = _gen;
    final next = _zonePage + 1;
    setState(() => _loadingMore = true);
    try {
      final tracks = await bili.musicZone(cateId: _zoneId, page: next);
      if (!mounted || gen != _gen) {
        return;
      }
      final seen = <String>{
        for (final item in _zone) item.bvid.isNotEmpty ? item.bvid : item.id,
      };
      final added = [
        for (final item in tracks)
          if (seen.add(item.bvid.isNotEmpty ? item.bvid : item.id)) item,
      ];
      setState(() {
        _zone.addAll(added);
        _zonePage = next;
        _zoneHasMore = added.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || gen != _gen) {
        return;
      }
      setState(() {
        _zoneHasMore = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final albums = albumsFromTracks(_zone);
    return RefreshIndicator(
      onRefresh: () => _loadZone(_zoneId, force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '发现',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: tokens.colorContrast,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _ZoneChips(selected: _zoneId, onSelected: _loadZone),
            ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _error!,
                    style: TextStyle(color: tokens.colorSecondary),
                  ),
                ),
              ),
            if (_loading && albums.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverToBoxAdapter(child: _DiscoverWaterfallSkeleton()),
              )
            else if (albums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    '这一分区暂时没有歌曲',
                    style: TextStyle(color: tokens.colorBase),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: context.listPadding(16, 14, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _DiscoverWaterfall(albums: albums),
                ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _DiscoverLoadMoreSkeleton(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoneChips extends StatelessWidget {
  const _ZoneChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: kMeluneMusicZones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final zone = kMeluneMusicZones[index];
          final active = zone.cateId == selected;
          return Material(
            color: active ? tokens.colorButtonBgSelected : tokens.colorButtonBg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: Key('music-zone-${zone.cateId}'),
              onTap: () => onSelected(zone.cateId),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  zone.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active
                        ? tokens.colorButtonTextSelected
                        : tokens.colorContrast,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiscoverWaterfallSkeleton extends StatelessWidget {
  const _DiscoverWaterfallSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1180
        ? 4
        : width >= 760
        ? 3
        : 2;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _WaterfallCardSkeleton(index: column + i * columns),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DiscoverLoadMoreSkeleton extends StatelessWidget {
  const _DiscoverLoadMoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: MeluneSkeleton(height: 112, radius: 12)),
        SizedBox(width: 8),
        Expanded(child: MeluneSkeleton(height: 112, radius: 12)),
      ],
    );
  }
}

class _WaterfallCardSkeleton extends StatelessWidget {
  const _WaterfallCardSkeleton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.colorRaisedBg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: switch (index % 4) {
              0 => 1.0,
              1 => 1.12,
              2 => 0.92,
              _ => 1.06,
            },
            child: const MeluneSkeleton(radius: 0),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeluneSkeleton(height: 13, radius: 6),
                SizedBox(height: 6),
                MeluneSkeleton(width: 88, height: 11, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverWaterfall extends StatelessWidget {
  const _DiscoverWaterfall({required this.albums});

  final List<MeluneAlbum> albums;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1180
        ? 4
        : width >= 760
        ? 3
        : 2;
    final buckets = List.generate(columns, (_) => <MeluneAlbum>[]);
    for (var i = 0; i < albums.length; i++) {
      buckets[i % columns].add(albums[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < buckets[column].length; i++) ...[
                  _WaterfallCard(
                    album: buckets[column][i],
                    index: column + i * columns,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WaterfallCard extends StatelessWidget {
  const _WaterfallCard({required this.album, required this.index});

  final MeluneAlbum album;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final plays = album.tracks.isEmpty
        ? ''
        : formatPlayCount(album.tracks.first.playCount);
    return Material(
      color: tokens.colorRaisedBg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('album-card-${album.id}'),
        onTap: () => BrowseScope.of(context).openAlbum(album),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: switch (index % 4) {
                0 => 1.0,
                1 => 1.12,
                2 => 0.92,
                _ => 1.06,
              },
              child: TrackCover(
                url: album.coverUrl,
                width: double.infinity,
                height: double.infinity,
                radius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.colorContrast,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      album.subtitle,
                      if (plays.isNotEmpty) '$plays 播放',
                    ].where((part) => part.isNotEmpty).join(' · '),
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
    );
  }
}
