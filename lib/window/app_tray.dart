import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:melune/window/window_controller.dart';
import 'package:tray_manager/tray_manager.dart';

class MeluneTray with TrayListener {
  MeluneTray._();

  static final MeluneTray instance = MeluneTray._();

  static String get _iconAsset {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'assets/tray/app_icon.ico';
    }
    return 'assets/tray/app_icon.png';
  }

  WindowController? _window;
  PlaybackStore? _playback;
  var _started = false;
  String _menuSig = '';
  String _tip = '';

  Future<void> start({
    required WindowController window,
    required PlaybackStore playback,
  }) async {
    if (!isDesktopWindow || _started) {
      return;
    }
    _started = true;
    _window = window;
    _playback = playback;
    try {
      await trayManager.setIcon(_iconAsset);
      trayManager.addListener(this);
      window.addListener(_refresh);
      playback.addListener(_refresh);
      await _refreshMenu(force: true);
    } catch (err) {
      _started = false;
      _window = null;
      _playback = null;
    }
  }

  Future<void> destroy() async {
    final window = _window;
    final playback = _playback;
    _window = null;
    _playback = null;
    _started = false;
    _menuSig = '';
    window?.removeListener(_refresh);
    playback?.removeListener(_refresh);
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
  }

  void _refresh() {
    unawaited(_refreshMenu());
  }

  Future<void> _refreshMenu({bool force = false}) async {
    final playback = _playback;
    final window = _window;
    if (playback == null || window == null) {
      return;
    }
    final title = playback.track == null ? '未在播放' : playback.displayTitle;
    final artist = playback.track?.artist ?? '';
    final sig = [
      title,
      artist,
      playback.playing,
      playback.liked,
      playback.desktopLyricOpen,
      playback.desktopLyricLocked,
      playback.lyricEffect.name,
      window.hiddenToTray,
    ].join('|');
    if (!force && sig == _menuSig) {
      return;
    }
    _menuSig = sig;
    final tip = playback.track == null
        ? 'Melune · 洛音'
        : artist.isEmpty
        ? title
        : '$title · $artist';
    try {
      if (force || tip != _tip) {
        _tip = tip;
        await trayManager.setToolTip(_clip(tip, 120));
      }
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'now_playing',
              label: _clip(title, 36),
              disabled: true,
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'toggle_window',
              label: window.hiddenToTray ? '显示主窗口' : '隐藏到托盘',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'play',
              label: playback.playing ? '暂停' : '播放',
              disabled: playback.track == null,
            ),
            MenuItem(key: 'previous', label: '上一首'),
            MenuItem(key: 'next', label: '下一首'),
            MenuItem.checkbox(
              key: 'like',
              label: playback.liked ? '已喜欢' : '喜欢',
              checked: playback.liked,
              disabled: playback.track == null,
            ),
            MenuItem.separator(),
            MenuItem.checkbox(
              key: 'lyric',
              label: '桌面歌词',
              checked: playback.desktopLyricOpen,
            ),
            MenuItem.checkbox(
              key: 'lyric_lock',
              label: '锁定歌词',
              checked: playback.desktopLyricLocked,
              disabled: !playback.desktopLyricOpen,
            ),
            MenuItem.submenu(
              key: 'lyric_effect',
              label: '歌词特效：${playback.lyricEffect.label}',
              submenu: Menu(
                items: [
                  for (final effect in DesktopLyricEffect.values)
                    MenuItem.checkbox(
                      key: 'effect_${effect.name}',
                      label: effect.label,
                      checked: playback.lyricEffect == effect,
                    ),
                ],
              ),
            ),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: '退出 Melune'),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_window?.showFromTray());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final playback = _playback;
    final window = _window;
    if (playback == null || window == null) {
      return;
    }
    switch (menuItem.key) {
      case 'toggle_window':
        if (window.hiddenToTray) {
          unawaited(window.showFromTray());
        } else {
          unawaited(window.hideToTray());
        }
      case 'play':
        unawaited(playback.togglePlay());
      case 'previous':
        unawaited(playback.previous());
      case 'next':
        unawaited(playback.next());
      case 'like':
        playback.toggleLike();
      case 'lyric':
        playback.toggleDesktopLyric();
      case 'lyric_lock':
        playback.toggleDesktopLyricLock();
      case 'effect_reel':
        playback.setDesktopLyricEffect(DesktopLyricEffect.reel);
      case 'effect_karaoke':
        playback.setDesktopLyricEffect(DesktopLyricEffect.karaoke);
      case 'effect_glow':
        playback.setDesktopLyricEffect(DesktopLyricEffect.glow);
      case 'effect_dual':
        playback.setDesktopLyricEffect(DesktopLyricEffect.dual);
      case 'quit':
        unawaited(_quit());
    }
  }

  Future<void> _quit() async {
    final playback = _playback;
    final window = _window;
    playback?.persistNow();
    playback?.hideDesktopLyric();
    await destroy();
    await window?.quit();
  }

  static String _clip(String text, int max) {
    final trimmed = text.trim();
    if (trimmed.length <= max) {
      return trimmed;
    }
    return '${trimmed.substring(0, max - 1)}…';
  }
}
