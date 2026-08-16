import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/accounts/accounts_popup.dart';
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
      _offlineBytes = PlaybackScope.read(context).offline.usedBytes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = PlaybackScope.read(context);
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
          padding: context.listPadding(16, 8, 16, 28),
          children: [
            Text('设置', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: '应用信息',
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: '关于',
                  subtitle: widget.appName,
                ),
                _SettingsTile(
                  icon: Icons.code_rounded,
                  title: '技术栈',
                  subtitle: 'Flutter + Rust · Bilibili Web API',
                ),
                if (widget.greet != null)
                  _SettingsTile(
                    icon: Icons.waving_hand_outlined,
                    title: 'Rust 握手',
                    subtitle: widget.greet!(name: '洛音'),
                  ),
              ],
            ),
            _SettingsGroup(
              title: '账号',
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: accounts.isLoggedIn
                      ? accounts.active?.name ?? '已登录'
                      : '未登录',
                  subtitle: accounts.isLoggedIn
                      ? '点心会进 Melune_ 前缀收藏夹，没有时会自动建 Melune_默认收藏'
                      : '登录后才能点心、同步收藏夹和拉大会员音质',
                  trailing: FilledButton.tonal(
                    onPressed: () => showAccountsPopup(context),
                    child: Text(accounts.isLoggedIn ? '管理' : '登录'),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: '外观',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SegmentedButton<MeluneThemeChoice>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MeluneThemeChoice.system,
                        label: Text('系统'),
                      ),
                      ButtonSegment(
                        value: MeluneThemeChoice.dark,
                        label: Text('深色'),
                      ),
                      ButtonSegment(
                        value: MeluneThemeChoice.light,
                        label: Text('浅色'),
                      ),
                    ],
                    selected: {settings.themeChoice},
                    onSelectionChanged: (value) {
                      settings.setThemeChoice(value.first);
                    },
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: '播放',
              children: [
                _DropdownTile<int>(
                  keyName: 'settings-quality',
                  icon: Icons.high_quality_outlined,
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
                  icon: Icons.repeat_rounded,
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
                  secondary: const _TileIcon(Icons.play_circle_outline_rounded),
                  title: const Text('续听时自动播放'),
                  subtitle: Text(
                    settings.resumeAutoplay
                        ? '下次打开会接着上次进度自动播'
                        : '下次打开会停在上次进度，按播放才继续',
                  ),
                  value: settings.resumeAutoplay,
                  onChanged: settings.setResumeAutoplay,
                ),
              ],
            ),
            _SettingsGroup(
              title: '均衡器',
              children: [
                SwitchListTile(
                  secondary: const _TileIcon(Icons.graphic_eq_rounded),
                  title: const Text('启用均衡器'),
                  subtitle: Text(
                    MeluneEqualizer.isDesktop
                        ? '通过播放器音频滤镜调节 10 段增益'
                        : '10 段参数会保存；Android 暂不接入系统 Equalizer，以免首次播放失败',
                  ),
                  value: settings.eqEnabled,
                  onChanged: (value) {
                    settings.setEqEnabled(value);
                    unawaited(player.applyOutputSettings());
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in MeluneEqualizer.presetLabels.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: false,
                          onSelected: (_) {
                            settings.setEqEnabled(true);
                            settings.setEqGains(
                              MeluneEqualizer.presets[entry.key]!,
                            );
                            unawaited(player.applyOutputSettings());
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 168,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
                                      value: settings.eqGains[i].clamp(
                                        -12,
                                        12,
                                      ),
                                      min: -12,
                                      max: 12,
                                      onChanged: settings.eqEnabled
                                          ? (value) =>
                                                settings.setEqBand(i, value)
                                          : null,
                                      onChangeEnd: (_) {
                                        settings.setEqGains(settings.eqGains);
                                        unawaited(
                                          player.applyOutputSettings(),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  MeluneEqualizer.bandLabels[i],
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (widget.window.enabled) ...[
              _SettingsGroup(
                title: '窗口与托盘',
                children: [
                  SwitchListTile(
                    key: const Key('settings-close-to-tray'),
                    secondary: const _TileIcon(Icons.inventory_2_outlined),
                    title: const Text('关闭窗口时隐藏到托盘'),
                    subtitle: Text(
                      settings.closeToTray
                          ? '点关闭或 Alt+F4 后继续在后台播放，从托盘右键退出才会结束进程'
                          : '点关闭会直接退出 Melune',
                    ),
                    value: settings.closeToTray,
                    onChanged: settings.setCloseToTray,
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.minimize_rounded),
                    title: const Text('启动后最小化到托盘'),
                    value: settings.startMinimized,
                    onChanged: settings.setStartMinimized,
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.power_settings_new_rounded),
                    title: const Text('开机启动'),
                    value: settings.launchAtStartup,
                    onChanged: (value) =>
                        unawaited(settings.setLaunchAtStartup(value)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: OutlinedButton.icon(
                      key: const Key('settings-quit'),
                      onPressed: widget.window.quit,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('退出 Melune'),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: '桌面歌词',
                children: [
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.lyrics_outlined),
                    title: const Text('显示桌面歌词'),
                    value: player.desktopLyricOpen,
                    onChanged: player.setDesktopLyricOpen,
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.play_arrow_outlined),
                    title: const Text('启动时打开桌面歌词'),
                    value: settings.desktopLyricOnStart,
                    onChanged: settings.setDesktopLyricOnStart,
                  ),
                  SwitchListTile(
                    secondary: const _TileIcon(Icons.lock_outline_rounded),
                    title: const Text('锁定桌面歌词'),
                    subtitle: const Text('锁定后歌词条点穿，不挡鼠标'),
                    value: player.desktopLyricLocked,
                    onChanged: player.setDesktopLyricLocked,
                  ),
                  _DropdownTile<DesktopLyricEffect>(
                    icon: Icons.auto_awesome_rounded,
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
              ),
            ],
            _SettingsGroup(
              title: '缓存',
              children: [
                _SettingsTile(
                  icon: Icons.folder_outlined,
                  title: '离线目录',
                  subtitle: settings.effectiveOfflineDir,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _offlineDir,
                    decoration: const InputDecoration(
                      labelText: '自定义离线目录（留空用默认）',
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
                ),
                _DropdownTile<int>(
                  icon: Icons.sd_storage_outlined,
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
                _SettingsTile(
                  icon: Icons.offline_pin_outlined,
                  title: '离线占用',
                  subtitle: _formatBytes(_offlineBytes),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: kIsWeb
                            ? null
                            : () => unawaited(
                                _openDir(settings.effectiveOfflineDir),
                              ),
                        child: const Text('打开离线目录'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: '快捷键',
              children: [
                const _SettingsTile(
                  icon: Icons.keyboard_alt_outlined,
                  title: '自定义快捷键',
                  subtitle: '窗口在前台时生效；缩到托盘后仍可用系统媒体键',
                ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextButton(
                    onPressed: settings.resetShortcuts,
                    child: const Text('恢复默认快捷键'),
                  ),
                ),
              ],
            ),
            _SettingsGroup(
              title: '代理',
              children: [
                SwitchListTile(
                  secondary: const _TileIcon(Icons.lan_outlined),
                  title: const Text('使用 HTTP 代理'),
                  subtitle: const Text(
                    '封面、歌词、离线和 B 站请求都会走这个代理；本机回环地址除外',
                  ),
                  value: settings.proxyEnabled,
                  onChanged: settings.setProxyEnabled,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _proxyHost,
                          enabled: settings.proxyEnabled,
                          decoration: const InputDecoration(labelText: '主机'),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: '端口'),
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
                ),
              ],
            ),
            _SettingsGroup(
              title: '实验功能',
              children: [
                SwitchListTile(
                  secondary: const _TileIcon(Icons.science_outlined),
                  title: const Text('跳过片头片尾静音'),
                  subtitle: const Text('部分平台有效，可能把弱音也裁掉'),
                  value: settings.skipSilence,
                  onChanged: (value) {
                    settings.setSkipSilence(value);
                    unawaited(player.applyOutputSettings());
                  },
                ),
              ],
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.primary),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _TileIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    super.key,
    this.keyName,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String? keyName;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: keyName == null ? null : Key(keyName!),
      leading: icon == null ? null : _TileIcon(icon!),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: PopupMenuButton<T>(
        initialValue: values.contains(value) ? value : values.first,
        tooltip: title,
        onSelected: onChanged,
        itemBuilder: (context) {
          return [
            for (final item in values)
              PopupMenuItem(value: item, child: Text(labelOf(item))),
          ];
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(labelOf(values.contains(value) ? value : values.first)),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final child = ListTile(
      leading: const _TileIcon(Icons.keyboard_outlined),
      title: Text(MeluneShortcuts.labels[widget.id] ?? widget.id),
      trailing: Text(
        widget.capturing ? '按下新按键…' : widget.binding,
        style: TextStyle(
          color: widget.capturing ? scheme.primary : scheme.onSurfaceVariant,
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
