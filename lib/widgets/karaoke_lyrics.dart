import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

class KaraokeLyrics extends StatefulWidget {
  const KaraokeLyrics({super.key, required this.player});

  final PlaybackStore player;

  @override
  State<KaraokeLyrics> createState() => _KaraokeLyricsState();
}

class _KaraokeLyricsState extends State<KaraokeLyrics> {
  final _controller = ScrollController();
  var _keys = <GlobalKey>[];
  var _active = -1;
  var _lineCount = 0;
  var _follow = true;
  var _scrollGen = 0;
  Timer? _resumeFollow;

  PlaybackStore get _player => widget.player;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayer);
    _adoptLines(_player.lyrics.length);
    _active = _player.activeLyricIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
  }

  @override
  void didUpdateWidget(KaraokeLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_onPlayer);
      widget.player.addListener(_onPlayer);
      _adoptLines(widget.player.lyrics.length);
      _active = widget.player.activeLyricIndex;
    }
  }

  @override
  void dispose() {
    _resumeFollow?.cancel();
    _player.removeListener(_onPlayer);
    _controller.dispose();
    super.dispose();
  }

  void _adoptLines(int count) {
    if (_lineCount == count && _keys.length == count) {
      return;
    }
    _keys = List<GlobalKey>.generate(count, (_) => GlobalKey());
    _lineCount = count;
    _active = -1;
    _follow = true;
  }

  void _onPlayer() {
    final count = _player.lyrics.length;
    final active = _player.activeLyricIndex;
    final linesChanged = count != _lineCount;
    if (linesChanged) {
      _adoptLines(count);
    }
    if (!linesChanged && active == _active) {
      return;
    }
    if (active < _active &&
        active <= 0 &&
        _player.position > const Duration(seconds: 2)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _active = active);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActive());
  }

  Future<void> _centerActive() async {
    if (!_follow || _active < 0 || _active >= _keys.length) {
      return;
    }
    if (!_controller.hasClients) {
      return;
    }
    final ctx = _keys[_active].currentContext;
    if (ctx == null) {
      return;
    }
    final gen = ++_scrollGen;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    if (gen != _scrollGen) {
      return;
    }
  }

  void _pauseFollow() {
    _follow = false;
    _resumeFollow?.cancel();
    _resumeFollow = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      _follow = true;
      _centerActive();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lines = _player.lyrics;

    if (lines.isEmpty) {
      return Center(
        child: Text(
          _player.track == null ? '播放歌曲后显示官方歌词' : '暂无官方字幕\n${_player.displayTitle}',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.colorBase, height: 1.5),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacer = (constraints.maxHeight * 0.36).clamp(96.0, 220.0);
        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              _pauseFollow();
            }
            return false;
          },
          child: ExcludeSemantics(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0, 0.1, 0.86, 1],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: RawScrollbar(
                  controller: _controller,
                  thumbVisibility: true,
                  thickness: 5,
                  radius: const Radius.circular(8),
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    key: const Key('now-playing-lyrics'),
                    controller: _controller,
                    padding: EdgeInsets.fromLTRB(24, spacer, 24, spacer),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < lines.length; index++)
                          _LyricLine(
                            key: _keys[index],
                            line: lines[index],
                            active: _active,
                            index: index,
                            tokens: tokens,
                            onTap: () {
                              _follow = true;
                              _resumeFollow?.cancel();
                              _player.seek(lines[index].from);
                            },
                          ),
                      ],
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

class _LyricLine extends StatelessWidget {
  const _LyricLine({
    super.key,
    required this.line,
    required this.active,
    required this.index,
    required this.tokens,
    required this.onTap,
  });

  final MeluneLyricLine line;
  final int active;
  final int index;
  final MeluneTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = line.content.split('\n');
    final primary = parts.first.trim();
    final secondary = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
    final distance = (index - active).abs();
    final isActive = index == active;
    final nearby = distance <= 2;
    final color = isActive
        ? tokens.colorBrand
        : tokens.colorBase.withValues(alpha: nearby ? 0.58 : 0.3);
    final secondaryColor = isActive
        ? tokens.colorBrand.withValues(alpha: 0.72)
        : tokens.colorBase.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: isActive ? 14 : 8),
        child: AnimatedScale(
          scale: isActive ? 1.06 : (nearby ? 1.0 : 0.96),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 380),
            opacity: isActive ? 1 : (nearby ? 0.82 : 0.4),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isActive ? 22 : 16,
                height: 1.35,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                color: color,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(primary, textAlign: TextAlign.center),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isActive ? 14 : 12,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                        color: secondaryColor,
                      ),
                      child: Text(secondary, textAlign: TextAlign.center),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
