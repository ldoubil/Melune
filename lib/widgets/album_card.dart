import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/track_cover.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    this.size = 148,
    this.onTap,
  });

  static const double height = 196;

  final MeluneAlbum album;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final coverSize = size - 20;
    return SizedBox(
      width: size,
      height: height,
      child: Material(
        color: tokens.colorRaisedBg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('album-card-${album.id}'),
          onTap: onTap ?? () => BrowseScope.of(context).openAlbum(album),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackCover(url: album.coverUrl, size: coverSize, radius: 14),
                const SizedBox(height: 8),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.colorContrast,
                  ),
                ),
                Text(
                  album.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.colorBase),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlbumGrid extends StatelessWidget {
  const AlbumGrid({
    super.key,
    required this.albums,
    this.padding,
  });

  final List<MeluneAlbum> albums;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 172,
        mainAxisExtent: AlbumCard.height,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) => Align(
        alignment: Alignment.topLeft,
        child: AlbumCard(album: albums[index]),
      ),
    );
  }
}

class AlbumStrip extends StatelessWidget {
  const AlbumStrip({
    super.key,
    required this.albums,
    required this.empty,
  });

  final List<MeluneAlbum> albums;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return Text(empty, style: TextStyle(color: context.tokens.colorBase));
    }
    return SizedBox(
      height: AlbumCard.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length.clamp(0, 12),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => AlbumCard(album: albums[index]),
      ),
    );
  }
}
