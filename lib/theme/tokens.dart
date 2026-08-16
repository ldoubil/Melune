import 'package:flutter/material.dart';

@immutable
class MeluneTokens extends ThemeExtension<MeluneTokens> {
  const MeluneTokens({
    required this.colorBg,
    required this.colorRaisedBg,
    required this.colorSuperRaisedBg,
    required this.colorDivider,
    required this.colorBase,
    required this.colorSecondary,
    required this.colorContrast,
    required this.colorButtonBg,
    required this.colorBrand,
    required this.colorBrandHighlight,
    required this.colorOnBrand,
    required this.colorButtonBgSelected,
    required this.colorButtonTextSelected,
  });

  final Color colorBg;
  final Color colorRaisedBg;
  final Color colorSuperRaisedBg;
  final Color colorDivider;
  final Color colorBase;
  final Color colorSecondary;
  final Color colorContrast;
  final Color colorButtonBg;
  final Color colorBrand;
  final Color colorBrandHighlight;
  final Color colorOnBrand;
  final Color colorButtonBgSelected;
  final Color colorButtonTextSelected;

  static const dark = MeluneTokens(
    colorBg: Color(0xFF16141C),
    colorRaisedBg: Color(0xFF27242E),
    colorSuperRaisedBg: Color(0xFF34313C),
    colorDivider: Color(0xFF42404A),
    colorBase: Color(0xFFB0BAC5),
    colorSecondary: Color(0xFF96A2B0),
    colorContrast: Color(0xFFFFFFFF),
    colorButtonBg: Color(0xFF34313C),
    colorBrand: Color(0xFFB794F6),
    colorBrandHighlight: Color(0x40B794F6),
    colorOnBrand: Color(0xFF140F1C),
    colorButtonBgSelected: Color(0x40B794F6),
    colorButtonTextSelected: Color(0xFFC4B5FD),
  );

  static const light = MeluneTokens(
    colorBg: Color(0xFFEBEBEB),
    colorRaisedBg: Color(0xFFF8F8F8),
    colorSuperRaisedBg: Color(0xFFFFFFFF),
    colorDivider: Color(0xFFDDDDDD),
    colorBase: Color(0xFF2C2E31),
    colorSecondary: Color(0xFF484D54),
    colorContrast: Color(0xFF1A202C),
    colorButtonBg: Color(0xFFFFFFFF),
    colorBrand: Color(0xFF5B4B8A),
    colorBrandHighlight: Color(0x405B4B8A),
    colorOnBrand: Color(0xFFFFFFFF),
    colorButtonBgSelected: Color(0xFF5B4B8A),
    colorButtonTextSelected: Color(0xFFFFFFFF),
  );

  @override
  MeluneTokens copyWith({
    Color? colorBg,
    Color? colorRaisedBg,
    Color? colorSuperRaisedBg,
    Color? colorDivider,
    Color? colorBase,
    Color? colorSecondary,
    Color? colorContrast,
    Color? colorButtonBg,
    Color? colorBrand,
    Color? colorBrandHighlight,
    Color? colorOnBrand,
    Color? colorButtonBgSelected,
    Color? colorButtonTextSelected,
  }) {
    return MeluneTokens(
      colorBg: colorBg ?? this.colorBg,
      colorRaisedBg: colorRaisedBg ?? this.colorRaisedBg,
      colorSuperRaisedBg: colorSuperRaisedBg ?? this.colorSuperRaisedBg,
      colorDivider: colorDivider ?? this.colorDivider,
      colorBase: colorBase ?? this.colorBase,
      colorSecondary: colorSecondary ?? this.colorSecondary,
      colorContrast: colorContrast ?? this.colorContrast,
      colorButtonBg: colorButtonBg ?? this.colorButtonBg,
      colorBrand: colorBrand ?? this.colorBrand,
      colorBrandHighlight: colorBrandHighlight ?? this.colorBrandHighlight,
      colorOnBrand: colorOnBrand ?? this.colorOnBrand,
      colorButtonBgSelected: colorButtonBgSelected ?? this.colorButtonBgSelected,
      colorButtonTextSelected:
          colorButtonTextSelected ?? this.colorButtonTextSelected,
    );
  }

  @override
  MeluneTokens lerp(ThemeExtension<MeluneTokens>? other, double t) {
    if (other is! MeluneTokens) {
      return this;
    }
    return MeluneTokens(
      colorBg: Color.lerp(colorBg, other.colorBg, t)!,
      colorRaisedBg: Color.lerp(colorRaisedBg, other.colorRaisedBg, t)!,
      colorSuperRaisedBg:
          Color.lerp(colorSuperRaisedBg, other.colorSuperRaisedBg, t)!,
      colorDivider: Color.lerp(colorDivider, other.colorDivider, t)!,
      colorBase: Color.lerp(colorBase, other.colorBase, t)!,
      colorSecondary: Color.lerp(colorSecondary, other.colorSecondary, t)!,
      colorContrast: Color.lerp(colorContrast, other.colorContrast, t)!,
      colorButtonBg: Color.lerp(colorButtonBg, other.colorButtonBg, t)!,
      colorBrand: Color.lerp(colorBrand, other.colorBrand, t)!,
      colorBrandHighlight:
          Color.lerp(colorBrandHighlight, other.colorBrandHighlight, t)!,
      colorOnBrand: Color.lerp(colorOnBrand, other.colorOnBrand, t)!,
      colorButtonBgSelected:
          Color.lerp(colorButtonBgSelected, other.colorButtonBgSelected, t)!,
      colorButtonTextSelected:
          Color.lerp(colorButtonTextSelected, other.colorButtonTextSelected, t)!,
    );
  }
}

extension MeluneTokensX on BuildContext {
  MeluneTokens get tokens {
    return Theme.of(this).extension<MeluneTokens>() ?? MeluneTokens.dark;
  }

  EdgeInsets listPadding(double left, double top, double right, double bottom) {
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + MediaQuery.paddingOf(this).bottom,
    );
  }
}

ThemeData buildMeluneTheme(MeluneTokens tokens, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.colorBrand,
    onPrimary: tokens.colorOnBrand,
    secondary: tokens.colorBrand,
    onSecondary: tokens.colorOnBrand,
    error: const Color(0xFFD93E5D),
    onError: Colors.white,
    surface: tokens.colorBg,
    onSurface: tokens.colorContrast,
    onSurfaceVariant: tokens.colorBase,
    outline: tokens.colorSecondary,
    outlineVariant: tokens.colorDivider,
    surfaceContainerLowest: tokens.colorBg,
    surfaceContainerLow: tokens.colorRaisedBg,
    surfaceContainer: tokens.colorRaisedBg,
    surfaceContainerHigh: tokens.colorSuperRaisedBg,
    surfaceContainerHighest: tokens.colorSuperRaisedBg,
  );
  final radius = BorderRadius.circular(16);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.colorBg,
    cardTheme: CardThemeData(
      color: tokens.colorRaisedBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: DividerThemeData(
      color: tokens.colorDivider,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.colorBrand,
      textColor: tokens.colorContrast,
      subtitleTextStyle: TextStyle(color: tokens.colorBase, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.colorOnBrand;
        }
        return tokens.colorSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.colorBrand;
        }
        return tokens.colorButtonBg;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: tokens.colorBrand,
      thumbColor: tokens.colorBrand,
      inactiveTrackColor: tokens.colorDivider,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.colorSuperRaisedBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.colorDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.colorBrand, width: 2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.colorOnBrand;
          }
          return tokens.colorContrast;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.colorBrand;
          }
          return tokens.colorSuperRaisedBg;
        }),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: tokens.colorButtonBgSelected,
      backgroundColor: tokens.colorButtonBg,
      labelStyle: TextStyle(color: tokens.colorContrast),
      side: BorderSide(color: tokens.colorDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    extensions: [tokens],
  );
}
