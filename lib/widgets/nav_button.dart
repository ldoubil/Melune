import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class NavButton extends StatefulWidget {
  const NavButton({
    super.key,
    this.icon,
    this.avatar,
    required this.label,
    required this.selected,
    required this.onTap,
    this.extended = false,
  });

  final IconData? icon;
  final Widget? avatar;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool extended;

  @override
  State<NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<NavButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color background;
    final Color iconColor;

    if (widget.selected) {
      background = tokens.colorButtonBgSelected;
      iconColor = tokens.colorButtonTextSelected;
    } else if (_hovering || _pressed) {
      background = tokens.colorButtonBg;
      iconColor = tokens.colorContrast;
    } else {
      background = tokens.colorButtonBg.withAlpha(0);
      iconColor = tokens.colorBase;
    }

    final mark = widget.avatar ?? Icon(widget.icon, size: 22, color: iconColor);
    final child = widget.extended
        ? _ExtendedFace(
            background: background,
            iconColor: iconColor,
            label: widget.label,
            mark: mark,
          )
        : _CompactFace(background: background, mark: mark);

    final button = MergeSemantics(
      child: Semantics(
        button: true,
        container: true,
        label: widget.label,
        selected: widget.selected,
        excludeSemantics: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: Transform.scale(
              scale: _pressed ? 0.97 : 1,
              child: child,
            ),
          ),
        ),
      ),
    );

    if (widget.extended) {
      return button;
    }

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 400),
      child: button,
    );
  }
}

class _CompactFace extends StatelessWidget {
  const _CompactFace({required this.background, required this.mark});

  final Color background;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(80),
          ),
          alignment: Alignment.center,
          child: mark,
        ),
      ),
    );
  }
}

class _ExtendedFace extends StatelessWidget {
  const _ExtendedFace({
    required this.background,
    required this.iconColor,
    required this.label,
    required this.mark,
  });

  final Color background;
  final Color iconColor;
  final String label;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, height: 26, child: Center(child: mark)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
