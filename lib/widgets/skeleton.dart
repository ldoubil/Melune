import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class MeluneSkeleton extends StatelessWidget {
  const MeluneSkeleton({super.key, this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.tokens.colorButtonBg,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class TrackTileSkeleton extends StatelessWidget {
  const TrackTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          MeluneSkeleton(width: 44, height: 44, radius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeluneSkeleton(height: 14, radius: 6),
                SizedBox(height: 8),
                MeluneSkeleton(width: 96, height: 10, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumCardSkeleton extends StatelessWidget {
  const AlbumCardSkeleton({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cover = size - 20;
    return SizedBox(
      width: size,
      height: 196,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MeluneSkeleton(width: cover, height: cover, radius: 14),
            const SizedBox(height: 8),
            const MeluneSkeleton(height: 14, radius: 6),
            const SizedBox(height: 6),
            const MeluneSkeleton(width: 72, height: 10, radius: 5),
          ],
        ),
      ),
    );
  }
}

class LibraryTileSkeleton extends StatelessWidget {
  const LibraryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 7, 14, 7),
      child: Row(
        children: [
          MeluneSkeleton(width: 36, height: 36, radius: 8),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MeluneSkeleton(height: 12, radius: 5),
                SizedBox(height: 6),
                MeluneSkeleton(width: 48, height: 9, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
