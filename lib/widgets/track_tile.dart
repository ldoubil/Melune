import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/queue_toggle.dart';
import 'package:melune/widgets/track_cache_button.dart';
import 'package:melune/widgets/track_cover.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.leading,
    this.trailing,
    this.highlighted = false,
  });

  final MeluneTrack track;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final minutes = track.duration.inMinutes;
    final seconds = track.duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final duration = track.durationSec > 0 ? '$minutes:$seconds' : '';

    return Material(
      color: highlighted ? tokens.colorBrandHighlight : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: tokens.colorButtonBg,
        splashColor: tokens.colorBrandHighlight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            children: [
              ?leading,
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
                        fontWeight: highlighted
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: highlighted
                            ? tokens.colorBrand
                            : tokens.colorContrast,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _ArtistLine(track: track, duration: duration),
                  ],
                ),
              ),
              trailing ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TrackCacheButton(track: track),
                      QueueToggleButton(track: track),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistLine extends StatelessWidget {
  const _ArtistLine({required this.track, required this.duration});

  final MeluneTrack track;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final artist = track.artist;
    final canOpen = track.upMid > 0 && artist.isNotEmpty;
    return Row(
      children: [
        if (artist.isNotEmpty)
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canOpen ? () => openArtistFromTrack(context, track) : null,
              child: Text(
                key: canOpen ? Key('track-artist-${track.upMid}') : null,
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: canOpen ? tokens.colorBrand : tokens.colorBase,
                ),
              ),
            ),
          ),
        if (artist.isNotEmpty && duration.isNotEmpty)
          Text(' · ', style: TextStyle(fontSize: 12, color: tokens.colorBase)),
        if (duration.isNotEmpty)
          Text(
            duration,
            style: TextStyle(fontSize: 12, color: tokens.colorBase),
          ),
      ],
    );
  }
}
