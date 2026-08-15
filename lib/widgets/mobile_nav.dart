import 'package:flutter/material.dart';
import 'package:melune/navigation.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/nav_button.dart';

class MeluneMobileNav extends StatelessWidget {
  const MeluneMobileNav({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.colorRaisedBg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < kMeluneDestinations.length; i++)
                NavButton(
                  key: Key('nav-${kMeluneDestinations[i].tab.name}'),
                  icon: index == i
                      ? kMeluneDestinations[i].selectedIcon
                      : kMeluneDestinations[i].icon,
                  label: kMeluneDestinations[i].label,
                  selected: index == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
