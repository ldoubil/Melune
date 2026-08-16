import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

class TrackCacheButton extends StatelessWidget {
  const TrackCacheButton({
    super.key,
    required this.track,
    this.deleting = false,
  });

  final MeluneTrack track;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.of(context);
    return ListenableBuilder(
      listenable: player.offline,
      builder: (context, _) {
        final cache = player.offline;
        final cached = cache.isCached(track);
        final error = cache.errorOf(track);
        final progress = cache.progressOf(track);
        final queued = cache.isQueued(track);
        if (cached || deleting) {
          return IconButton(
            key: Key('track-cache-${track.id}'),
            tooltip: cached ? '删除离线缓存' : '下载离线缓存',
            visualDensity: VisualDensity.compact,
            onPressed: cached
                ? () => cache.remove(track)
                : () => player.cacheTracks([track]),
            icon: Icon(
              cached ? Icons.download_done_rounded : Icons.download_outlined,
              color: cached ? tokens.colorBrand : tokens.colorBase,
            ),
          );
        }
        if (queued) {
          return SizedBox(
            key: Key('track-cache-${track.id}'),
            width: 40,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Tooltip(
                message: error ?? '正在缓存 ${(progress ?? 0) * 100 ~/ 1}%',
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  value: error != null
                      ? 1
                      : (progress ?? 0.08).clamp(0.08, 1),
                  color: error != null
                      ? tokens.colorSecondary
                      : tokens.colorBrand,
                ),
              ),
            ),
          );
        }
        return IconButton(
          key: Key('track-cache-${track.id}'),
          tooltip: '下载离线缓存',
          visualDensity: VisualDensity.compact,
          onPressed: () => player.cacheTracks([track]),
          icon: Icon(Icons.download_outlined, color: tokens.colorBase),
        );
      },
    );
  }
}

class AlbumCacheButton extends StatelessWidget {
  const AlbumCacheButton({super.key, required this.tracks});

  final List<MeluneTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.of(context);
    return ListenableBuilder(
      listenable: player.offline,
      builder: (context, _) {
        if (tracks.isEmpty) {
          return const SizedBox.shrink();
        }
        final cache = player.offline;
        final (done, total) = cache.albumProgress(tracks);
        final allCached = total > 0 && done >= total;
        final working = tracks.any(cache.isQueued);
        return OutlinedButton.icon(
          key: const Key('album-cache'),
          onPressed: allCached
              ? () => cache.removeAll(tracks)
              : () => player.cacheTracks(tracks),
          icon: Icon(
            allCached
                ? Icons.download_done_rounded
                : working
                ? Icons.downloading_rounded
                : Icons.download_rounded,
          ),
          label: Text(
            allCached
                ? '已缓存'
                : working
                ? '缓存中 $done/$total'
                : done > 0
                ? '缓存全部 $done/$total'
                : '缓存全部',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: allCached || working
                ? tokens.colorBrand
                : tokens.colorContrast,
          ),
        );
      },
    );
  }
}
