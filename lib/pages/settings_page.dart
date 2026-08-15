import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.appName,
    this.greet,
  });

  final String appName;
  final String Function({required String name})? greet;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: context.listPadding(16, 12, 16, 22),
      children: [
        _InfoRow(
          icon: Icons.info_outline,
          iconColor: tokens.colorBrand,
          title: '关于',
          subtitle: appName,
        ),
        const _InfoRow(
          icon: Icons.code,
          title: '技术栈',
          subtitle: 'Flutter + Rust · Bilibili Web API',
        ),
        const _InfoRow(
          icon: Icons.memory_outlined,
          title: '核心',
          subtitle: 'flutter_rust_bridge · WBI · Cookie 会话',
        ),
        if (greet != null)
          _InfoRow(
            icon: Icons.waving_hand_outlined,
            title: 'Rust 握手',
            subtitle: greet!(name: '洛音'),
          ),
      ],
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
