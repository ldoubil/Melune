import 'package:flutter/material.dart';
import 'package:melune/accounts/account_avatar.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/accounts/accounts_popup.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/navigation.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/library_rail.dart';
import 'package:melune/widgets/nav_button.dart';

class MeluneSideNav extends StatelessWidget {
  const MeluneSideNav({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onOpenAlbum,
  });

  static const double width = 220;

  final int index;
  final ValueChanged<int> onSelect;
  final void Function(MeluneAlbum album) onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final store = AccountScope.of(context);

    return SizedBox(
      width: width,
      child: ColoredBox(
        color: tokens.colorRaisedBg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Text(
                  '导航',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.colorSecondary,
                  ),
                ),
              ),
              for (var i = 0; i < kMeluneMainDestinations.length; i++)
                NavButton(
                  key: Key('nav-${kMeluneMainDestinations[i].tab.name}'),
                  icon: index == i
                      ? kMeluneMainDestinations[i].selectedIcon
                      : kMeluneMainDestinations[i].icon,
                  label: kMeluneMainDestinations[i].label,
                  selected: index == i,
                  extended: true,
                  onTap: () => onSelect(i),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.colorDivider,
                ),
              ),
              Expanded(child: LibraryRail(onOpenAlbum: onOpenAlbum)),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final active = store.active;
                  return NavButton(
                    key: const Key('nav-account'),
                    avatar: active == null
                        ? Icon(
                            Icons.person_outline,
                            size: 22,
                            color: tokens.colorBase,
                          )
                        : AccountAvatar(name: active.name, face: active.face),
                    label: active?.name ?? '账号',
                    selected: false,
                    extended: true,
                    onTap: () => showAccountsPopup(context),
                  );
                },
              ),
              NavButton(
                key: const Key('nav-settings'),
                icon: index == kMeluneSettingsIndex
                    ? kMeluneSettingsDestination.selectedIcon
                    : kMeluneSettingsDestination.icon,
                label: kMeluneSettingsDestination.label,
                selected: index == kMeluneSettingsIndex,
                extended: true,
                onTap: () => onSelect(kMeluneSettingsIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
