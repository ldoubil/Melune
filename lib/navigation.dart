import 'package:flutter/material.dart';

enum MeluneTab { home, search, favorites, settings }

class MeluneDestination {
  const MeluneDestination({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final MeluneTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const kMeluneMainDestinations = [
  MeluneDestination(
    tab: MeluneTab.home,
    label: '主页',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  MeluneDestination(
    tab: MeluneTab.search,
    label: '搜索',
    icon: Icons.search,
    selectedIcon: Icons.search,
  ),
  MeluneDestination(
    tab: MeluneTab.favorites,
    label: '收藏',
    icon: Icons.favorite_outline,
    selectedIcon: Icons.favorite,
  ),
];

const kMeluneSettingsDestination = MeluneDestination(
  tab: MeluneTab.settings,
  label: '设置',
  icon: Icons.settings_outlined,
  selectedIcon: Icons.settings,
);

const kMeluneDestinations = [
  ...kMeluneMainDestinations,
  kMeluneSettingsDestination,
];

const kMeluneSettingsIndex = 3;
