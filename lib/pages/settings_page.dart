import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/accounts/accounts_popup.dart';
import 'package:melune/player/cover_cache.dart';
import 'package:melune/player/equalizer.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/settings/app_settings.dart';
import 'package:melune/settings/shortcuts.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/window/desktop_lyric.dart';
import 'package:melune/window/window_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.appName,
    required this.window,
    this.greet,
  });

  final String appName;
  final WindowController window;
  final String Function({required String name})? greet;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _proxyHost;
  late final TextEditingController _proxyPort;
  late final TextEditingController _offlineDir;
  var _coverBytes = 0;
  var _offlineBytes = 0;
  String? _capturingShortcut;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance;
    _proxyHost = TextEditingController(text: settings.proxyHost);
    _proxyPort = TextEditingController(text: '${settings.proxyPort}');
    _offlineDir = TextEditingController(text: settings.offlineDir);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverBytes = CoverCache.instance.usedBytes();
    _offlineBytes = PlaybackScope.read(context).offline.usedBytes();
  }

  @override
  void dispose() {
    MeluneShortcuts.capturing = false;
    _proxyHost.dispose();
    _proxyPort.dispose();
    _offlineDir.dispose();
    super.dispose();
  }

  void _refreshCacheSizes() {
    setState(() {
      _coverBytes = CoverCache.instance.usedBytes();
      _offlineBytes = PlaybackScope.read(context).offline.usedBytes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.of(context);
    final accounts = AccountScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettings.instance,
        player,
        accounts,
      ]),
      builder: (context, _) {
        final settings = AppSettings.instance;
        return ListView(
          padding: context.listPadding(16, 12, 16, 22),
          children: [
            Text(
              '设置',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tokens.colorContrast,
              ),
            ),
            const SizedBox(height: 16),
            _SectionLabel('应用信息'),
            _InfoRow(
              icon: Icons.info_outline,
              iconColor: tokens.colorBrand,
              title: '关于',
              subtitle: widget.appName,
            ),
            const _InfoRow(
              icon: Icons.code,
              title: '技术栈',
              subtitle: 'Flutter + Rust · Bilibili Web API',
            ),
            if (widget.greet != null)
              _InfoRow(
                icon: Icons.waving_hand_outlined,
                title: 'Rust 握手',
                subtitle: widget.greet!(name: '洛音'),
              ),
            const SizedBox(height: 12),
            _SectionLabel('外观'),
            _ChoiceTiles<MeluneThemeChoice>(
              value: settings.themeChoice,
              onChanged: settings.setThemeChoice,
              items: const [
                (MeluneThemeChoice.system, '跟随系统'),
                (MeluneThemeChoice.dark, '深色'),
                (MeluneThemeChoice.light, '浅色'),
              ],
            ),
            const SizedBox(height: 18),
            _SectionLabel('播放'),
            _DropdownTile<int>(
              keyName: 'settings-quality',
              title: '默认音质',
              subtitle: '播放和新缓存都会按这个档位去要流',
              value: settings.preferredQualityId,
              values: const [0, 30280, 30232, 30216, 30251, 30250],
              labelOf: _qualityLabel,
              onChanged: (value) {
                settings.setPreferredQualityId(value);
                unawaited(player.setQuality(value));
              },
            ),
            _DropdownTile<int>(
              keyName: 'settings-mode',
              title: '播放模式',
              value: player.playbackMode.index,
              values: [
                for (var i = 0; i < PlaybackMode.values.length; i++) i,
              ],
              labelOf: (index) => PlaybackMode.values[index].label,
              onChanged: (value) {
                player.setPlaybackMode(PlaybackMode.values[value]);
              },
            ),
            _SliderTile(
              title: '音量',
              value: player.volume,
              min: 0,
              max: 1,
              label: '${(player.volume * 100).round()}%',
              onChanged: (value) => unawaited(player.setVolume(value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.resumeAutoplay,
              activeThumbColor: tokens.colorOnBrand,
              activeTrackColor: tokens.colorBrand,
              title: Text(
                '续听时自动播放',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.colorContrast,
                ),
              ),
              subtitle: Text(
                settings.resumeAutoplay
                    ? '下次打开会接着上次进度自动播'
                    : '下次打开会停在上次进度，按播放才继续',
                style: TextStyle(color: tokens.colorBase, fontSize: 13),
              ),
              onChanged: settings.setResumeAutoplay,
            ),
            const SizedBox(height: 8),
            _SectionLabel('均衡器'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.eqEnabled,
              activeThumbColor: tokens.colorOnBrand,
              activeTrackColor: tokens.colorBrand,
              title: Text(
                '启用均衡器',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.colorContrast,
                ),
              ),
              subtitle: Text(
                MeluneEqualizer.isDesktop
                    ? '通过播放器音频滤镜调节 10 段增益'
                    : '在支持的系统上按频段调节增益',
                style: TextStyle(color: tokens.colorBase, fontSize: 13),
              ),
              onChanged: (value) {
                settings.setEqEnabled(value);
                unawaited(player.applyOutputSettings());
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in MeluneEqualizer.presetLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: false,
                    onSelected: (_) {
                      settings.setEqEnabled(true);
                      settings.setEqGains(MeluneEqualizer.presets[entry.key]!);
                      unawaited(player.applyOutputSettings());
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  for (var i = 0; i < MeluneEqualizer.bandsHz.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: settings.eqGains[i].clamp(-12, 12),
                                min: -12,
                                max: 12,
                                onChanged: settings.eqEnabled
                                    ? (value) => settings.setEqBand(i, value)
                                    : null,
                                onChangeEnd: (_) {
                                  settings.setEqGains(settings.eqGains);
                                  unawaited(player.applyOutputSettings());
                                },
                              ),
                            ),
                          ),
                          Text(
                            MeluneEqualizer.bandLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: tokens.colorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.window.enabled) ...[
              const SizedBox(height: 10),
              _SectionLabel('窗口与托盘'),
              SwitchListTile(
                key: const Key('settings-close-to-tray'),
                contentPadding: EdgeInsets.zero,
                value: settings.closeToTray,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '关闭窗口时隐藏到托盘',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                subtitle: Text(
                  settings.closeToTray
                      ? '点关闭或 Alt+F4 后继续在后台播放，从托盘右键退出才会结束进程'
                      : '点关闭会直接退出 Melune',
                  style: TextStyle(color: tokens.colorBase, fontSize: 13),
                ),
                onChanged: settings.setCloseToTray,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.startMinimized,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '启动后最小化到托盘',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                onChanged: settings.setStartMinimized,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.launchAtStartup,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '开机启动',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                onChanged: (value) => unawaited(settings.setLaunchAtStartup(value)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('settings-quit'),
                  onPressed: widget.window.quit,
                  icon: Icon(Icons.logout_rounded, color: tokens.colorBase),
                  label: Text(
                    '退出 Melune',
                    style: TextStyle(color: tokens.colorContrast),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SectionLabel('桌面歌词'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: player.desktopLyricOpen,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '显示桌面歌词',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                onChanged: player.setDesktopLyricOpen,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.desktopLyricOnStart,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '启动时打开桌面歌词',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                onChanged: settings.setDesktopLyricOnStart,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: player.desktopLyricLocked,
                activeThumbColor: tokens.colorOnBrand,
                activeTrackColor: tokens.colorBrand,
                title: Text(
                  '锁定桌面歌词',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                subtitle: Text(
                  '锁定后歌词条点穿，不挡鼠标',
                  style: TextStyle(color: tokens.colorBase, fontSize: 13),
                ),
                onChanged: player.setDesktopLyricLocked,
              ),
              _DropdownTile<DesktopLyricEffect>(
                title: '歌词特效',
                value: player.lyricEffect,
                values: DesktopLyricEffect.values,
                labelOf: (effect) => effect.label,
                onChanged: player.setDesktopLyricEffect,
              ),
              _SliderTile(
                title: '歌词不透明度',
                value: settings.lyricOpacity,
                min: 0.2,
                max: 1,
                label: '${(settings.lyricOpacity * 100).round()}%',
                onChanged: (value) {
                  settings.setLyricOpacity(value);
                  unawaited(player.applyOutputSettings());
                },
              ),
            ],
            const SizedBox(height: 10),
            _SectionLabel('缓存'),
            _InfoRow(
              icon: Icons.folder_outlined,
              title: '离线目录',
              subtitle: settings.effectiveOfflineDir,
            ),
            TextField(
              controller: _offlineDir,
              style: TextStyle(color: tokens.colorContrast),
              decoration: InputDecoration(
                labelText: '自定义离线目录（留空用默认）',
                labelStyle: TextStyle(color: tokens.colorSecondary),
              ),
              onSubmitted: (value) {
                settings.setOfflineDir(value);
                unawaited(player.offline.restore());
                _refreshCacheSizes();
              },
              onEditingComplete: () {
                settings.setOfflineDir(_offlineDir.text);
                unawaited(player.offline.restore());
                _refreshCacheSizes();
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: kIsWeb
                    ? null
                    : () => unawaited(_openDir(settings.effectiveOfflineDir)),
                child: const Text('打开离线目录'),
              ),
            ),
            _DropdownTile<int>(
              title: '离线容量上限',
              subtitle: '超出后会从最旧的缓存开始清理',
              value: settings.offlineMaxMb,
              values: const [512, 1024, 2048, 4096, 8192, 0],
              labelOf: (value) => value <= 0 ? '不限制' : '$value MB',
              onChanged: (value) {
                settings.setOfflineMaxMb(value);
                unawaited(player.offline.enforceLimit());
                _refreshCacheSizes();
              },
            ),
            _InfoRow(
              icon: Icons.offline_pin_outlined,
              title: '离线占用',
              subtitle: _formatBytes(_offlineBytes),
            ),
            _InfoRow(
              icon: Icons.image_outlined,
              title: '封面缓存',
              subtitle: _formatBytes(_coverBytes),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await CoverCache.instance.clearAll();
                  if (mounted) {
                    _refreshCacheSizes();
                  }
                },
                child: const Text('清封面缓存'),
              ),
            ),
            const SizedBox(height: 8),
            _SectionLabel('快捷键'),
            Text(
              '窗口在前台时生效；缩到托盘后仍可用系统媒体键',
              style: TextStyle(color: tokens.colorBase, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final id in MeluneShortcuts.ids)
              _ShortcutRow(
                id: id,
                capturing: _capturingShortcut == id,
                binding: settings.shortcutOf(
                  id,
                  MeluneShortcuts.defaults[id] ?? '',
                ),
                onCapture: () {
                  MeluneShortcuts.capturing = true;
                  setState(() => _capturingShortcut = id);
                },
                onEvent: (event) {
                  if (MeluneShortcuts.isModifierOnly(event)) {
                    return;
                  }
                  settings.setShortcut(id, MeluneShortcuts.encode(event));
                  MeluneShortcuts.capturing = false;
                  setState(() => _capturingShortcut = null);
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: settings.resetShortcuts,
                child: const Text('恢复默认快捷键'),
              ),
            ),
            const SizedBox(height: 8),
            _SectionLabel('代理'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.proxyEnabled,
              activeThumbColor: tokens.colorOnBrand,
              activeTrackColor: tokens.colorBrand,
              title: Text(
                '使用 HTTP 代理',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.colorContrast,
                ),
              ),
              subtitle: Text(
                '封面、歌词、离线和 B 站请求都会走这个代理；本机回环地址除外',
                style: TextStyle(color: tokens.colorBase, fontSize: 13),
              ),
              onChanged: settings.setProxyEnabled,
            ),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _proxyHost,
                    enabled: settings.proxyEnabled,
                    style: TextStyle(color: tokens.colorContrast),
                    decoration: InputDecoration(
                      labelText: '主机',
                      labelStyle: TextStyle(color: tokens.colorSecondary),
                    ),
                    onSubmitted: settings.setProxyHost,
                    onEditingComplete: () =>
                        settings.setProxyHost(_proxyHost.text),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _proxyPort,
                    enabled: settings.proxyEnabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: tokens.colorContrast),
                    decoration: InputDecoration(
                      labelText: '端口',
                      labelStyle: TextStyle(color: tokens.colorSecondary),
                    ),
                    onSubmitted: (value) {
                      settings.setProxyPort(int.tryParse(value) ?? 7890);
                    },
                    onEditingComplete: () {
                      settings.setProxyPort(
                        int.tryParse(_proxyPort.text) ?? 7890,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionLabel('账号'),
            _InfoRow(
              icon: Icons.person_outline,
              iconColor: tokens.colorBrand,
              title: accounts.isLoggedIn
                  ? accounts.active?.name ?? '已登录'
                  : '未登录',
              subtitle: accounts.isLoggedIn
                  ? '点心会进 Melune_ 前缀收藏夹，没有时会自动建 Melune_默认收藏'
                  : '登录后才能点心、同步收藏夹和拉大会员音质',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showAccountsPopup(context),
                child: Text(accounts.isLoggedIn ? '管理账号' : '扫码登录'),
              ),
            ),
            const SizedBox(height: 12),
            _SectionLabel('实验功能'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.skipSilence,
              activeThumbColor: tokens.colorOnBrand,
              activeTrackColor: tokens.colorBrand,
              title: Text(
                '跳过片头片尾静音',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.colorContrast,
                ),
              ),
              subtitle: Text(
                '部分平台有效，可能把弱音也裁掉',
                style: TextStyle(color: tokens.colorBase, fontSize: 13),
              ),
              onChanged: (value) {
                settings.setSkipSilence(value);
                unawaited(player.applyOutputSettings());
              },
            ),
          ],
        );
      },
    );
  }

  String _qualityLabel(int id) {
    return switch (id) {
      0 => '自动（最高可用）',
      30280 => '192Kbps',
      30232 => '132Kbps',
      30216 => '64Kbps',
      30251 => 'Hi-Res 无损',
      30250 => '杜比全景声',
      _ => '$id',
    };
  }

  Future<void> _openDir(String path) async {
    try {
      await Directory(path).create(recursive: true);
      if (Platform.isWindows) {
        await Process.start('explorer', [path.replaceAll('/', r'\')]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [path]);
      } else {
        await Process.start('xdg-open', [path]);
      }
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.tokens.colorSecondary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? tokens.colorBase),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.colorContrast,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: tokens.colorBase)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTiles<T> extends StatelessWidget {
  const _ChoiceTiles({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$2),
            selected: value == item.$1,
            onSelected: (_) => onChanged(item.$1),
          ),
      ],
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    super.key,
    this.keyName,
    required this.title,
    this.subtitle,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String? keyName;
  final String title;
  final String? subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      key: keyName == null ? null : Key(keyName!),
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: tokens.colorContrast,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: tokens.colorBase, fontSize: 13),
            ),
      trailing: DropdownButton<T>(
        value: values.contains(value) ? value : values.first,
        underline: const SizedBox.shrink(),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(labelOf(item))),
        ],
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.colorContrast,
                ),
              ),
            ),
            Text(label, style: TextStyle(color: tokens.colorBase)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  const _ShortcutRow({
    required this.id,
    required this.binding,
    required this.capturing,
    required this.onCapture,
    required this.onEvent,
  });

  final String id;
  final String binding;
  final bool capturing;
  final VoidCallback onCapture;
  final ValueChanged<KeyEvent> onEvent;

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_ShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.capturing && !oldWidget.capturing) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final child = ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        MeluneShortcuts.labels[widget.id] ?? widget.id,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: tokens.colorContrast,
        ),
      ),
      trailing: Text(
        widget.capturing ? '按下新按键…' : widget.binding,
        style: TextStyle(
          color: widget.capturing ? tokens.colorBrand : tokens.colorBase,
        ),
      ),
      onTap: widget.onCapture,
    );
    if (!widget.capturing) {
      return child;
    }
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: widget.onEvent,
      child: child,
    );
  }
}
