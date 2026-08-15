import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:window_manager/window_manager.dart';

Future<void> runDesktopLyricWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(920, 128),
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
    await windowManager.show();
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
  const height = 120.0;
  final left = (screen.width - width) / 2;
  final top = screen.height - height - 72;
  await windowManager.setBounds(Rect.fromLTWH(left, top, width, height));
}

class DesktopLyricApp extends StatefulWidget {
  const DesktopLyricApp({super.key});

  @override
  State<DesktopLyricApp> createState() => _DesktopLyricAppState();
}

class _DesktopLyricAppState extends State<DesktopLyricApp>
    with WindowListener {
  var _snapshot = const DesktopLyricSnapshot();
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
  }

  Future<void> _bind() async {
    await _down.setMethodCallHandler(_onHost);
    await _applyLock(_snapshot.locked);
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
        await _applyLock(next.locked);
        if (next.visible) {
          await windowManager.show();
        } else {
          await windowManager.hide();
        }
        return null;
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<void> _applyLock(bool locked) async {
    await windowManager.setIgnoreMouseEvents(locked, forward: true);
    await windowManager.setAlwaysOnTop(true);
  }

  @override
  void onWindowClose() {
    windowManager.hide();
    _up.invokeMethod('closed');
  }

  @override
  void dispose() {
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
          snapshot: _snapshot,
          onLike: () => _up.invokeMethod('toggleLike'),
          onLock: () => _up.invokeMethod('toggleLock'),
        ),
      ),
    );
  }
}

class DesktopLyricBar extends StatelessWidget {
  const DesktopLyricBar({
    super.key,
    required this.snapshot,
    required this.onLike,
    required this.onLock,
  });

  final DesktopLyricSnapshot snapshot;
  final VoidCallback onLike;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final locked = snapshot.locked;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Material(
            color: tokens.colorRaisedBg.withValues(alpha: 0.62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  TrackCover(url: snapshot.coverUrl, size: 52, radius: 12),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: snapshot.liked ? '取消收藏' : '收藏',
                    visualDensity: VisualDensity.compact,
                    onPressed: locked ? null : onLike,
                    icon: Icon(
                      snapshot.liked ? Icons.favorite : Icons.favorite_border,
                      color: snapshot.liked
                          ? tokens.colorBrand
                          : tokens.colorBase,
                    ),
                  ),
                  Expanded(
                    child: DragToMoveArea(
                      child: _LyricStack(snapshot: snapshot, tokens: tokens),
                    ),
                  ),
                  IconButton(
                    tooltip: locked ? '解锁桌面歌词（可拖动）' : '锁定桌面歌词（点穿）',
                    visualDensity: VisualDensity.compact,
                    onPressed: locked ? null : onLock,
                    icon: Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: tokens.colorBrand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricStack extends StatelessWidget {
  const _LyricStack({required this.snapshot, required this.tokens});

  final DesktopLyricSnapshot snapshot;
  final MeluneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final previous = _firstLine(snapshot.previous);
    final current = _split(snapshot.current);
    final next = _firstLine(snapshot.next);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (previous.isNotEmpty)
          Text(
            previous,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: tokens.colorBase.withValues(alpha: 0.58),
            ),
          ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: tokens.colorBrand,
          ),
          child: AnimatedScale(
            scale: 1.06,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: Text(
              current.$1.isEmpty
                  ? (snapshot.title.isEmpty ? 'Melune · 洛音' : snapshot.title)
                  : current.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (current.$2.isNotEmpty)
          Text(
            current.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: tokens.colorBrand.withValues(alpha: 0.72),
            ),
          )
        else if (next.isNotEmpty)
          Text(
            next,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: tokens.colorBase.withValues(alpha: 0.58),
            ),
          ),
      ],
    );
  }

  static String _firstLine(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  static (String, String) _split(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return ('', '');
    }
    return (lines.first, lines.length > 1 ? lines.sublist(1).join(' ') : '');
  }
}
