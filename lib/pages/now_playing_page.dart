import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/player/format_time.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/audio_quality.dart';
import 'package:melune/widgets/karaoke_lyrics.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/widgets/volume_button.dart';

class NowPlayingGate extends StatefulWidget {
  const NowPlayingGate({super.key});

  @override
  State<NowPlayingGate> createState() => _NowPlayingGateState();
}

class _NowPlayingGateState extends State<NowPlayingGate>
    with SingleTickerProviderStateMixin {
  PlaybackStore? _store;
  var _open = false;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = PlaybackScope.read(context);
    if (!identical(_store, store)) {
      _store?.removeListener(_onStore);
      _store = store;
      _syncOpen(store.nowPlayingOpen, animate: false);
      store.addListener(_onStore);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    _controller.dispose();
    super.dispose();
  }

  void _onStore() {
    _syncOpen(_store?.nowPlayingOpen ?? false, animate: true);
  }

  void _syncOpen(bool open, {required bool animate}) {
    if (open == _open) {
      return;
    }
    _open = open;
    if (!animate) {
      _controller.value = open ? 1 : 0;
      return;
    }
    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: SlideTransition(
        position: _slide,
        child: const ExcludeSemantics(child: NowPlayingPage()),
      ),
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  PlaybackStore? _player;
  var _expanded = false;
  String? _trackId;
  PageController? _pager;

  PlaybackStore get player => _player!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = PlaybackScope.read(context);
    if (identical(_player, store)) {
      return;
    }
    _player?.removeListener(_onPlayer);
    _player = store;
    _expanded = store.lyricsExpanded;
    _trackId = store.track?.id;
    _pager ??= PageController(initialPage: store.lyricsExpanded ? 1 : 0);
    store.addListener(_onPlayer);
  }

  @override
  void dispose() {
    _pager?.dispose();
    _player?.removeListener(_onPlayer);
    super.dispose();
  }

  void _onPlayer() {
    final expanded = player.lyricsExpanded;
    final trackId = player.track?.id;
    if (expanded == _expanded && trackId == _trackId) {
      return;
    }
    setState(() {
      _expanded = expanded;
      _trackId = trackId;
    });
    final pager = _pager;
    final target = expanded ? 1 : 0;
    if (pager != null && pager.hasClients && pager.page?.round() != target) {
      pager.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = this.player;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SeekRow(player: player),
          const SizedBox(height: 4),
          _TransportRow(player: player),
          if (player.error != null) ...[
            const SizedBox(height: 12),
            Text(
              player.error!,
              style: TextStyle(color: tokens.colorSecondary),
            ),
          ],
        ],
      ),
    );

    return Material(
      key: const Key('now-playing-page'),
      color: tokens.colorBg,
      child: SafeArea(
        child: Column(
          children: [
            _NowPlayingChrome(player: player),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Expanded(child: _CoverAndTitle(player: player)),
                            controls,
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: _LyricsPane(player: player),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pager,
                          physics: const BouncingScrollPhysics(
                            parent: PageScrollPhysics(),
                          ),
                          onPageChanged: (index) {
                            player.setLyricsExpanded(index == 1);
                          },
                          children: [
                            _CoverAndTitle(player: player),
                            _LyricsPane(player: player),
                          ],
                        ),
                      ),
                      _PageDots(index: _expanded ? 1 : 0),
                      controls,
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class _NowPlayingChrome extends StatelessWidget {
  const _NowPlayingChrome({required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('now-playing-back'),
            tooltip: '返回',
            onPressed: player.closeNowPlaying,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: tokens.colorContrast),
          ),
          Expanded(
            child: Text(
              '正在播放',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.colorContrast,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _CoverAndTitle extends StatelessWidget {
  const _CoverAndTitle({required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final track = player.track;
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = (constraints.maxHeight * 0.58).clamp(120.0, 280.0);
        return Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedScale(
                      scale: player.playing ? 1 : 0.94,
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 480),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: player.playing
                              ? [
                                  BoxShadow(
                                    color: tokens.colorBrand.withValues(alpha: 0.28),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ]
                              : const [],
                        ),
                        child: TrackCover(
                          url: track?.coverUrl ?? '',
                          size: coverSize,
                          radius: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  player.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: tokens.colorContrast,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  track?.artist.isNotEmpty == true ? track!.artist : 'Bilibili 音乐',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.colorBrand,
                  ),
                ),
                const SizedBox(height: 10),
                const _Tag(label: '音乐'),
              ],
            ),
          );
      },
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index
                    ? tokens.colorBrand
                    : tokens.colorBase.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _LyricsPane extends StatelessWidget {
  const _LyricsPane({required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 12),
      child: Material(
        color: tokens.colorBrand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: KeyedSubtree(
          key: const Key('now-playing-lyrics-pane'),
          child: KaraokeLyrics(player: player),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.colorBrand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.colorBrand,
        ),
      ),
    );
  }
}

class _SeekRow extends StatelessWidget {
  const _SeekRow({required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final tokens = context.tokens;
        final progress = player.duration.inMilliseconds == 0
            ? 0.0
            : player.position.inMilliseconds / player.duration.inMilliseconds;

        return ExcludeSemantics(
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: tokens.colorBrand,
                  inactiveTrackColor: tokens.colorDivider,
                  thumbColor: tokens.colorBrand,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (value) {
                    player.seek(
                      Duration(
                        milliseconds: (value * player.duration.inMilliseconds).round(),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Text(
                      formatPlayerTime(player.position),
                      style: TextStyle(fontSize: 12, color: tokens.colorBase),
                    ),
                    const Spacer(),
                    Text(
                      formatPlayerTime(player.duration),
                      style: TextStyle(fontSize: 12, color: tokens.colorBase),
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

class _TransportRow extends StatelessWidget {
  const _TransportRow({required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final showVolume =
        !compact && defaultTargetPlatform != TargetPlatform.android;

    return PlaybackSelect(
      player: player,
      selector: (store) => (
        store.playing,
        store.liked,
        store.playbackMode,
        store.loading,
        store.qualityLabel,
        store.volume,
      ),
      builder: (context, store) {
        final mode = store.playbackMode;
        final left = [
          IconButton(
            tooltip: store.liked ? '取消收藏' : '收藏',
            onPressed: store.toggleLike,
            icon: Icon(
              store.liked ? Icons.favorite : Icons.favorite_border,
              color: store.liked ? tokens.colorBrand : tokens.colorBase,
            ),
          ),
          IconButton(
            tooltip: mode.label,
            onPressed: store.cyclePlaybackMode,
            icon: Icon(
              mode.icon,
              color: mode.emphasized ? tokens.colorBrand : tokens.colorBase,
            ),
          ),
          IconButton(
            tooltip: '上一首',
            onPressed: store.previous,
            icon: Icon(Icons.skip_previous_rounded, color: tokens.colorContrast),
          ),
        ];
        final right = [
          IconButton(
            tooltip: '下一首',
            onPressed: store.next,
            icon: Icon(Icons.skip_next_rounded, color: tokens.colorContrast),
          ),
          AudioQualityButton(player: store),
          IconButton(
            tooltip: '播放列表',
            onPressed: () => _showQueue(context, store),
            icon: Icon(Icons.queue_music_rounded, color: tokens.colorBase),
          ),
          if (showVolume) VolumeButton(player: store),
        ];

        return Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: left),
              ),
            ),
            Material(
              color: tokens.colorBrand,
              shape: const CircleBorder(),
              child: InkWell(
                key: const Key('now-playing-play'),
                customBorder: const CircleBorder(),
                onTap: store.loading || store.track == null
                    ? null
                    : store.togglePlay,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: store.loading
                      ? Padding(
                          padding: const EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tokens.colorOnBrand,
                          ),
                        )
                      : Icon(
                          store.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                          color: tokens.colorOnBrand,
                        ),
                ),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: right),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showQueue(BuildContext context, PlaybackStore player) {
  final tokens = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: tokens.colorRaisedBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          if (player.queue.isEmpty) {
            return SizedBox(
              height: 180,
              child: Center(
                child: Text('播放队列是空的', style: TextStyle(color: tokens.colorBase)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: player.queue.length,
            itemBuilder: (context, index) {
              final item = player.queue[index];
              final current = player.track?.id == item.id;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    player.playAt(index);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                            color: current ? tokens.colorBrand : tokens.colorContrast,
                          ),
                        ),
                        Text(
                          item.artist,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12, color: tokens.colorBase),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
