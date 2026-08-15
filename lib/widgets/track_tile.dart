import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/queue_toggle.dart';
import 'package:melune/widgets/track_cover.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.highlighted = false,
  });

  final MeluneTrack track;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final minutes = track.duration.inMinutes;
    final seconds = track.duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              TrackCover(url: track.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                        color: highlighted ? tokens.colorBrand : tokens.colorContrast,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (track.artist.isNotEmpty) track.artist,
                        if (track.durationSec > 0) '$minutes:$seconds',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.colorBase),
                    ),
                  ],
                ),
              ),
              trailing ?? QueueToggleButton(track: track),
            ],
          ),
        ),
      ),
    );
  }
}
