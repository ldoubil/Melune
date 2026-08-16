import 'dart:async';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:melune/theme/tokens.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<bool> _lyricWindowVisible = ValueNotifier(false);

Future<void> runDesktopLyricWindow() async {
  await windowManager.ensureInitialized();
  try {
    await acrylic.Window.initialize();
    await acrylic.Window.setEffect(effect: acrylic.WindowEffect.transparent);
  } catch (_) {}
  const options = WindowOptions(
    size: Size(920, 148),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('Melune · 桌面歌词');
    try {
      await windowManager.setHasShadow(false);
    } catch (_) {}
    try {
      await windowManager.setResizable(false);
    } catch (_) {}
    await _placeLyricBar();
    if (_lyricWindowVisible.value) {
      await windowManager.show();
    } else {
      await windowManager.hide();
    }
  });
  runApp(const DesktopLyricApp());
}

Future<void> _placeLyricBar() async {
  final displays = PlatformDispatcher.instance.displays;
  if (displays.isEmpty) {
    return;
  }
  final display = displays.first;
  final screen = display.size / display.devicePixelRatio;
  final width = (screen.width * 0.74).clamp(420.0, 1120.0);
  const height = 148.0;
  final left = (screen.width - width) / 2;
  final top = screen.height - height - 72;
  await windowManager.setBounds(Rect.fromLTWH(left, top, width, height));
}

class DesktopLyricApp extends StatefulWidget {
  const DesktopLyricApp({super.key});

  @override
  State<DesktopLyricApp> createState() => _DesktopLyricAppState();
}

class _DesktopLyricAppState extends State<DesktopLyricApp> with WindowListener {
  var _snapshot = const DesktopLyricSnapshot();
  var _passingThrough = false;
  var _hovered = false;
  DateTime? _shownAt;
  final _lockKey = GlobalKey();
  final _barKey = GlobalKey();
  Timer? _hitTestTimer;
  static const _down = WindowMethodChannel(
    kDesktopLyricDownChannel,
    mode: ChannelMode.unidirectional,
  );
  static const _up = WindowMethodChannel(
    kDesktopLyricUpChannel,
    mode: ChannelMode.unidirectional,
  );

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _bind();
    _hitTestTimer = Timer.periodic(
      const Duration(milliseconds: 48),
      (_) => unawaited(_syncPassThrough()),
    );
  }

  Future<void> _bind() async {
    await _down.setMethodCallHandler(_onHost);
    await _syncPassThrough();
  }

  Future<dynamic> _onHost(MethodCall call) async {
    switch (call.method) {
      case 'state':
        final raw = call.arguments;
        final map = switch (raw) {
          final Map map => Map<String, dynamic>.from(map),
          _ => <String, dynamic>{},
        };
        final next = DesktopLyricSnapshot.fromMap(map);
        if (!mounted) {
          return null;
        }
        setState(() => _snapshot = next);
        _lyricWindowVisible.value = next.visible;
        await windowManager.setAlwaysOnTop(true);
        if (next.visible) {
          await windowManager.show();
          _shownAt = DateTime.now();
          try {
            await windowManager.setOpacity(next.opacity.clamp(0.2, 1.0));
          } catch (_) {}
        } else {
          _shownAt = null;
          await _setClickThrough(false);
          await windowManager.hide();
        }
        await _syncPassThrough();
        return null;
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<void> _syncPassThrough() async {
    var overChrome = false;
    var overBar = false;
    try {
      final cursor = await screenRetriever.getCursorScreenPoint();
      final window = await windowManager.getBounds();
      overChrome =
          _rectOf(_lockKey, window)?.inflate(16).contains(cursor) ?? false;
      overBar = _rectOf(_barKey, window)?.contains(cursor) ?? false;
    } catch (_) {}
    if (mounted && _hovered != overBar) {
      setState(() => _hovered = overBar);
    }
    final shownLongEnough =
        _shownAt != null &&
        DateTime.now().difference(_shownAt!) >
            const Duration(milliseconds: 240);
    final ignore =
        _snapshot.locked && _snapshot.visible && shownLongEnough && !overChrome;
    await _setClickThrough(ignore);
  }

  Future<void> _setClickThrough(bool ignore) async {
    if (ignore == _passingThrough) {
      return;
    }
    _passingThrough = ignore;
    try {
      await windowManager.setIgnoreMouseEvents(ignore, forward: true);
      await windowManager.setOpacity(1);
      if (!ignore) {
        await windowManager.setBackgroundColor(Colors.transparent);
        try {
          await acrylic.Window.setEffect(
            effect: acrylic.WindowEffect.transparent,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Rect? _rectOf(GlobalKey key, Rect window) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      window.left + origin.dx,
      window.top + origin.dy,
      box.size.width,
      box.size.height,
    );
  }

  @override
  void onWindowClose() {
    windowManager.hide();
    _up.invokeMethod('closed');
  }

  @override
  void dispose() {
    _hitTestTimer?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: buildMeluneTheme(MeluneTokens.dark, Brightness.dark),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: DesktopLyricBar(
          barKey: _barKey,
          chromeKey: _lockKey,
          snapshot: _snapshot,
          hovered: _hovered,
          onHover: (value) {
            if (_hovered != value) {
              setState(() => _hovered = value);
            }
          },
          onLock: () => _up.invokeMethod('toggleLock'),
          onCycleEffect: () => _up.invokeMethod('cycleEffect'),
        ),
      ),
    );
  }
}

class DesktopLyricBar extends StatelessWidget {
  const DesktopLyricBar({
    super.key,
    required this.barKey,
    required this.chromeKey,
    required this.snapshot,
    required this.hovered,
    required this.onHover,
    required this.onLock,
    required this.onCycleEffect,
  });

  final Key barKey;
  final GlobalKey chromeKey;
  final DesktopLyricSnapshot snapshot;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onLock;
  final VoidCallback onCycleEffect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final locked = snapshot.locked;
    final effect = _effectView(snapshot, tokens);
    final body = Column(
      key: barKey,
      children: [
        SizedBox(
          height: 36,
          child: AnimatedOpacity(
            opacity: hovered ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !hovered,
              child: Row(
                key: chromeKey,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: locked ? '解锁桌面歌词（可拖动）' : '锁定桌面歌词（点穿）',
                    visualDensity: VisualDensity.compact,
                    onPressed: onLock,
                    icon: Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black87),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '歌词特效：${snapshot.effect.label}',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCycleEffect,
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: locked ? effect : DragToMoveArea(child: effect)),
      ],
    );
    if (locked) {
      return body;
    }
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: body,
    );
  }

  Widget _effectView(DesktopLyricSnapshot snapshot, MeluneTokens tokens) {
    return switch (snapshot.effect) {
      DesktopLyricEffect.reel => _LyricReel(snapshot: snapshot, tokens: tokens),
      DesktopLyricEffect.karaoke => _LyricKaraoke(
        snapshot: snapshot,
        tokens: tokens,
      ),
      DesktopLyricEffect.glow => _LyricGlow(snapshot: snapshot, tokens: tokens),
      DesktopLyricEffect.dual => _LyricDual(snapshot: snapshot, tokens: tokens),
    };
  }
}

class _LyricReel extends StatefulWidget {
  const _LyricReel({required this.snapshot, required this.tokens});

  final DesktopLyricSnapshot snapshot;
  final MeluneTokens tokens;

  @override
  State<_LyricReel> createState() => _LyricReelState();
}

class _LyricReelState extends State<_LyricReel>
    with SingleTickerProviderStateMixin {
  static const _slot = 36.0;
  late final AnimationController _controller;
  var _previous = '';
  var _current = '';
  var _next = '';
  String? _incoming;
  var _direction = 1;

  @override
  void initState() {
    super.initState();
    _previous = _lyricSide(widget.snapshot.previous);
    _current = _lyricHero(widget.snapshot);
    _next = _lyricSide(widget.snapshot.next);
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 480),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _commit();
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LyricReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCurrent = _lyricHero(widget.snapshot);
    final nextSide = _lyricSide(widget.snapshot.next);
    final prevSide = _lyricSide(widget.snapshot.previous);
    if (nextCurrent == _current &&
        nextSide == _next &&
        prevSide == _previous &&
        !_controller.isAnimating) {
      return;
    }
    if (_controller.isAnimating) {
      return;
    }
    if (nextCurrent == _next && _next.isNotEmpty) {
      _incoming = nextSide;
      _direction = 1;
      _controller.forward(from: 0);
      return;
    }
    if (nextCurrent == _previous && _previous.isNotEmpty) {
      _incoming = prevSide;
      _direction = -1;
      _controller.forward(from: 0);
      return;
    }
    setState(() {
      _previous = prevSide;
      _current = nextCurrent;
      _next = nextSide;
      _incoming = null;
    });
  }

  void _commit() {
    if (!mounted) {
      return;
    }
    setState(() {
      _previous = _lyricSide(widget.snapshot.previous);
      _current = _lyricHero(widget.snapshot);
      _next = _lyricSide(widget.snapshot.next);
      _incoming = null;
      _direction = 1;
    });
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final lines = _direction >= 0
            ? [_previous, _current, _next, _incoming ?? '']
            : [_incoming ?? '', _previous, _current, _next];
        final shift = _direction >= 0
            ? -progress * _slot
            : -_slot + progress * _slot;
        return ClipRect(
          child: SizedBox(
            height: _slot * 3,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: i * _slot + shift,
                    height: _slot,
                    child: _LyricLine(
                      text: lines[i],
                      centerDistance:
                          ((i * _slot + shift + _slot / 2) - _slot * 1.5).abs(),
                      slot: _slot,
                      tokens: widget.tokens,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _lyricHero(DesktopLyricSnapshot snapshot) {
  final current = _lyricSide(snapshot.current);
  if (current.isNotEmpty) {
    return current;
  }
  if (snapshot.title.isNotEmpty) {
    return snapshot.title;
  }
  return 'Melune · 洛音';
}

String _lyricSide(String text) {
  return text
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
}

class _LyricLine extends StatelessWidget {
  const _LyricLine({
    required this.text,
    required this.centerDistance,
    required this.slot,
    required this.tokens,
  });

  final String text;
  final double centerDistance;
  final double slot;
  final MeluneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = (centerDistance / slot).clamp(0.0, 1.0);
    final color = Color.lerp(
      tokens.colorBrand,
      Colors.white.withValues(alpha: 0.62),
      t,
    )!;
    return Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: lerpDouble(22, 14, t),
          height: 1.2,
          fontWeight: t < 0.45 ? FontWeight.w800 : FontWeight.w500,
          color: color,
          shadows: _lyricShadow,
        ),
      ),
    );
  }
}

const _lyricShadow = [
  Shadow(blurRadius: 10, color: Colors.black87),
  Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black54),
];

class _LyricKaraoke extends StatelessWidget {
  const _LyricKaraoke({required this.snapshot, required this.tokens});

  final DesktopLyricSnapshot snapshot;
  final MeluneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final current = _lyricHero(snapshot);
    final progress = snapshot.progress.clamp(0.0, 1.0);
    final fill = progress.clamp(0.02, 0.98);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dimLyric(_lyricSide(snapshot.previous), 13),
          const SizedBox(height: 4),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  tokens.colorBrand,
                  tokens.colorBrand,
                  Colors.white.withValues(alpha: 0.42),
                  Colors.white.withValues(alpha: 0.42),
                ],
                stops: [0, fill, fill, 1],
              ).createShader(bounds);
            },
            child: Text(
              current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: _lyricShadow,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _dimLyric(_lyricSide(snapshot.next), 13),
        ],
      ),
    );
  }
}

class _LyricGlow extends StatefulWidget {
  const _LyricGlow({required this.snapshot, required this.tokens});

  final DesktopLyricSnapshot snapshot;
  final MeluneTokens tokens;

  @override
  State<_LyricGlow> createState() => _LyricGlowState();
}

class _LyricGlowState extends State<_LyricGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _lyricHero(widget.snapshot);
    final tokens = widget.tokens;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dimLyric(_lyricSide(widget.snapshot.previous), 13),
              Transform.scale(
                scale: 1 + 0.045 * t,
                child: Text(
                  current,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Color.lerp(
                      tokens.colorBrand,
                      Colors.white,
                      0.18 * t,
                    ),
                    shadows: [
                      Shadow(
                        blurRadius: 10 + 18 * t,
                        color: tokens.colorBrand.withValues(
                          alpha: 0.35 + 0.45 * t,
                        ),
                      ),
                      Shadow(
                        blurRadius: 6 + 10 * t,
                        color: Colors.white.withValues(alpha: 0.18 * t),
                      ),
                      const Shadow(blurRadius: 8, color: Colors.black87),
                    ],
                  ),
                ),
              ),
              _dimLyric(_lyricSide(widget.snapshot.next), 13),
            ],
          ),
        );
      },
    );
  }
}

class _LyricDual extends StatelessWidget {
  const _LyricDual({required this.snapshot, required this.tokens});

  final DesktopLyricSnapshot snapshot;
  final MeluneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final current = _lyricHero(snapshot);
    final next = _lyricSide(snapshot.next);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Text(
              current,
              key: ValueKey(current),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: tokens.colorBrand,
                shadows: _lyricShadow,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: next.isEmpty ? 0 : 0.78,
            child: Text(
              next,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Color(0xB3FFFFFF),
                shadows: _lyricShadow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dimLyric(String text, double size) {
  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.48),
      shadows: _lyricShadow,
    ),
  );
}
