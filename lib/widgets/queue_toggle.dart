import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

class QueueToggleButton extends StatelessWidget {
  const QueueToggleButton({super.key, required this.track});

  final MeluneTrack track;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.read(context);
    return PlaybackSelect(
      player: player,
      selector: (store) => store.isQueued(track),
      builder: (context, store) {
        final queued = store.isQueued(track);
        return IconButton(
          key: Key('queue-toggle-${track.id}'),
          tooltip: queued ? '移出播放列表' : '加入播放列表',
          visualDensity: VisualDensity.compact,
          onPressed: () => store.toggleQueued(track),
          icon: Icon(
            queued
                ? Icons.playlist_add_check_rounded
                : Icons.playlist_add_rounded,
            color: queued ? tokens.colorBrand : tokens.colorBase,
          ),
        );
      },
    );
  }
}

void showQueueMessage(BuildContext context, int added) {
  final text = added <= 0
      ? '已经在播放列表里了'
      : added == 1
          ? '已加入播放列表'
          : '已加入 $added 首';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1200),
      ),
    );
}
