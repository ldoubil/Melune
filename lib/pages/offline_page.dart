import 'package:flutter/material.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/track_cache_button.dart';
import 'package:melune/widgets/track_tile.dart';

class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.of(context);
    return ListenableBuilder(
      listenable: player.offline,
      builder: (context, _) {
        final cache = player.offline;
        final jobs = cache.jobs;
        final tracks = cache.tracks;
        return Material(
          key: const Key('offline-page'),
          color: tokens.colorBg,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('offline-back'),
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: tokens.colorContrast,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '离线缓存',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (tracks.isNotEmpty)
                      TextButton(
                        key: const Key('offline-clear'),
                        onPressed: () => cache.removeAll(tracks),
                        child: Text(
                          '清空',
                          style: TextStyle(color: tokens.colorBase),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    cache.busy
                        ? '已缓存 ${tracks.length} 首 · 正在下载 ${cache.activeCount} 首'
                        : tracks.isEmpty
                        ? '还没有离线歌曲'
                        : '已缓存 ${tracks.length} 首',
                    style: TextStyle(color: tokens.colorBase, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: jobs.isEmpty && tracks.isEmpty
                    ? Center(
                        child: Text(
                          '点歌曲旁的下载，或在歌单里缓存全部',
                          style: TextStyle(color: tokens.colorBase),
                        ),
                      )
                    : ListView(
                        padding: context.listPadding(12, 0, 8, 24),
                        children: [
                          for (final job in jobs)
                            Column(
                              children: [
                                TrackTile(
                                  track: job.track,
                                  onTap: () =>
                                      player.playTracks([job.track, ...tracks]),
                                  trailing: TrackCacheButton(track: job.track),
                                ),
                                if (job.error != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      72,
                                      0,
                                      16,
                                      8,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        job.error!,
                                        style: TextStyle(
                                          color: tokens.colorSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      72,
                                      0,
                                      16,
                                      10,
                                    ),
                                    child: LinearProgressIndicator(
                                      value: job.progress.clamp(0.08, 1),
                                      color: tokens.colorBrand,
                                      minHeight: 3,
                                    ),
                                  ),
                              ],
                            ),
                          for (var i = 0; i < tracks.length; i++)
                            TrackTile(
                              track: tracks[i],
                              onTap: () => player.playTracks(tracks, start: i),
                              trailing: TrackCacheButton(
                                track: tracks[i],
                                deleting: true,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
