import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class ChromeButton extends StatefulWidget {
  const ChromeButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  final double iconSize;

  @override
  State<ChromeButton> createState() => _ChromeButtonState();
}

class _ChromeButtonState extends State<ChromeButton> {
  bool _hovering = false;
  bool _pressed = false;

  static const _danger = Color(0xFFD93E5D);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color background;
    final Color iconColor;

    if (widget.danger && _hovering) {
      background = _danger;
      iconColor = Colors.white;
    } else if (_hovering || _pressed) {
      background = tokens.colorButtonBg;
      iconColor = tokens.colorContrast;
    } else {
      background = tokens.colorButtonBg.withAlpha(0);
      iconColor = tokens.colorBase;
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() {
          _hovering = false;
          _pressed = false;
        }),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Transform.scale(
            scale: _pressed ? 0.9 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
