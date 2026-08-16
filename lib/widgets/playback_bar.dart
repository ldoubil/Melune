import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/player/format_time.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/audio_quality.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/widgets/track_like_button.dart';
import 'package:melune/widgets/volume_button.dart';
import 'package:melune/window/window_controller.dart';

class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key});

  static const double height = 84;
  static const EdgeInsets margin = EdgeInsets.fromLTRB(12, 8, 12, 12);

  static double overlayExtent() {
    return margin.vertical + height;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.read(context);
    final compact = MediaQuery.sizeOf(context).width < 860;

    return PlaybackSelect(
      player: player,
      selector: (store) => (
        store.track?.id,
        store.displayTitle,
        store.liked,
        store.playing,
        store.loading,
        store.queue.length,
        store.volume,
        store.error,
        store.qualityLabel,
        store.selectedQualityId,
        store.playlistOpen,
        store.desktopLyricOpen,
      ),
      builder: (context, store) {
        return Padding(
          padding: margin,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Material(
                color: tokens.colorRaisedBg.withValues(alpha: 0.62),
                child: InkWell(
                  key: const Key('playback-lyrics'),
                  onTap: store.openNowPlaying,
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          _TrackInfo(player: store, compact: compact),
                          Expanded(
                            child: _Transport(player: store, compact: compact),
                          ),
                          _Extras(player: store, compact: compact),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.player, required this.compact});

  final PlaybackStore player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final track = player.track;

    return SizedBox(
      width: compact ? 132 : 220,
      key: const Key('playback-now-playing'),
      child: Row(
        children: [
          TrackCover(url: track?.coverUrl ?? ''),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.colorContrast,
                  ),
                ),
                Text(
                  track?.artist ?? 'Melune',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.colorBase),
                ),
              ],
            ),
          ),
          TrackLikeButton(player: player, compact: true),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.player, required this.compact});

  final PlaybackStore player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一首',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: player.previous,
              icon: Icon(
                Icons.skip_previous_rounded,
                color: tokens.colorContrast,
              ),
            ),
            Material(
              color: tokens.colorBrand,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('playback-play'),
                customBorder: const CircleBorder(),
                onTap: player.togglePlay,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: tokens.colorOnBrand,
                      ),
                      if (player.loading)
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: tokens.colorOnBrand.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '下一首',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: player.next,
              icon: Icon(Icons.skip_next_rounded, color: tokens.colorContrast),
            ),
          ],
        ),
        if (!compact)
          ListenableBuilder(
            listenable: player.progressListenable,
            builder: (context, _) {
              final progress = player.duration.inMilliseconds == 0
                  ? 0.0
                  : player.position.inMilliseconds /
                        player.duration.inMilliseconds;
              return ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        formatPlayerTime(player.position),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: tokens.colorBase),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          activeTrackColor: tokens.colorBrand,
                          inactiveTrackColor: tokens.colorBrand.withValues(
                            alpha: 0.22,
                          ),
                          thumbColor: tokens.colorBrand,
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            player.seek(
                              Duration(
                                milliseconds:
                                    (value * player.duration.inMilliseconds)
                                        .round(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        formatPlayerTime(player.duration),
                        style: TextStyle(fontSize: 11, color: tokens.colorBase),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Extras extends StatelessWidget {
  const _Extras({required this.player, required this.compact});

  final PlaybackStore player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showVolume =
        !compact && defaultTargetPlatform != TargetPlatform.android;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AudioQualityButton(player: player),
        if (!compact && isDesktopWindow)
          IconButton(
            key: const Key('playback-desktop-lyric'),
            tooltip: player.desktopLyricOpen
                ? '关闭桌面歌词 · 长按切换特效'
                : '桌面歌词 · 长按切换特效',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: player.toggleDesktopLyric,
            onLongPress: player.cycleDesktopLyricEffect,
            icon: Icon(
              Icons.lyrics_rounded,
              color: player.desktopLyricOpen
                  ? context.tokens.colorBrand
                  : context.tokens.colorBase,
            ),
          ),
        IconButton(
          key: const Key('playback-playlist'),
          tooltip: '播放列表',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: player.togglePlaylist,
          icon: Icon(
            Icons.queue_music_rounded,
            color: player.playlistOpen
                ? context.tokens.colorBrand
                : context.tokens.colorBase,
          ),
        ),
        if (showVolume) VolumeButton(player: player),
      ],
    );
  }
}
