import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/track_cover.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.name,
    this.face = '',
    this.size = 28,
  });

  final String name;
  final String face;
  final double size;

  static String initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  static Color accentFor(String name, MeluneTokens tokens) {
    final hash = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final hues = <Color>[
      tokens.colorBrand,
      const Color(0xFF5865F2),
      const Color(0xFFE67E22),
      const Color(0xFF3BA55D),
      const Color(0xFFEB459E),
    ];
    return hues[hash % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (face.isNotEmpty) {
      return ClipOval(
        child: TrackCover(
          url: face,
          size: size,
          radius: 0,
          fallback: _Initial(name: name, size: size, tokens: tokens),
        ),
      );
    }
    return _Initial(name: name, size: size, tokens: tokens);
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size, this.tokens});

  final String name;
  final double size;
  final MeluneTokens? tokens;

  @override
  Widget build(BuildContext context) {
    final palette = tokens ?? context.tokens;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AccountAvatar.accentFor(name, palette),
        shape: BoxShape.circle,
      ),
      child: Text(
        AccountAvatar.initialFor(name),
        style: TextStyle(
          color: palette.colorOnBrand,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
