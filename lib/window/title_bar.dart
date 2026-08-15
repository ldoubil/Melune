import 'package:flutter/material.dart';
import 'package:melune/accounts/account_avatar.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/accounts/accounts_popup.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/chrome_button.dart';
import 'package:melune/widgets/nav_button.dart';
import 'package:melune/window/window_controller.dart';

class MeluneTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const MeluneTitleBar({
    super.key,
    required this.window,
    required this.appName,
    this.showAccount = false,
    this.searchController,
    this.onSearch,
  });

  static const double height = 56;

  final WindowController window;
  final String appName;
  final bool showAccount;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: window,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                GestureDetector(
                  key: const Key('window-drag-area'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart:
                      window.enabled ? (_) => window.startDragging() : null,
                  onDoubleTap:
                      window.enabled ? () => window.toggleMaximize() : null,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.graphic_eq,
                          size: 22,
                          color: tokens.colorBrand,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          appName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tokens.colorContrast,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart:
                        window.enabled ? (_) => window.startDragging() : null,
                    onDoubleTap:
                        window.enabled ? () => window.toggleMaximize() : null,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: TextField(
                            key: const Key('title-search-field'),
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: onSearch,
                            style: TextStyle(
                              color: tokens.colorContrast,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: '搜索歌曲',
                              hintStyle: TextStyle(
                                color: tokens.colorBase,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: tokens.colorBase,
                                size: 18,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: tokens.colorBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showAccount) const _TitleAccountButton(),
                if (window.enabled) ...[
                  ChromeButton(
                    key: const Key('window-minimize'),
                    icon: Icons.horizontal_rule,
                    tooltip: '最小化',
                    onTap: () => window.minimize(),
                  ),
                  ChromeButton(
                    key: const Key('window-maximize'),
                    icon: window.isMaximized
                        ? Icons.filter_none
                        : Icons.crop_square_outlined,
                    tooltip: window.isMaximized ? '还原' : '最大化',
                    iconSize: window.isMaximized ? 14 : 18,
                    onTap: () => window.toggleMaximize(),
                  ),
                  ChromeButton(
                    key: const Key('window-close'),
                    icon: Icons.close,
                    tooltip: '关闭',
                    danger: true,
                    onTap: () => window.close(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleAccountButton extends StatelessWidget {
  const _TitleAccountButton();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final store = AccountScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final active = store.active;
        return NavButton(
          key: const Key('nav-account'),
          avatar: active == null
              ? Icon(Icons.person_outline, size: 22, color: tokens.colorBase)
              : AccountAvatar(name: active.name, face: active.face),
          label: active?.name ?? '账号',
          selected: false,
          onTap: () => showAccountsPopup(context),
        );
      },
    );
  }
}
