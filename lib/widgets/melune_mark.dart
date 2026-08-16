import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class MeluneMark extends StatelessWidget {
  const MeluneMark({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MeluneMarkPainter(color ?? context.tokens.colorBrand),
    );
  }
}

class _MeluneMarkPainter extends CustomPainter {
  const _MeluneMarkPainter(this.color);

  final Color color;

  static const _heights = [0.42, 0.70, 1.0, 0.70, 0.42];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    const count = 5;
    const gapFactor = 0.42;
    final barWidth = size.width / (count + (count - 1) * gapFactor);
    final gap = barWidth * gapFactor;
    final radius = Radius.circular(barWidth / 2);
    for (var i = 0; i < count; i++) {
      final height = (size.height * _heights[i]).clamp(barWidth, size.height);
      final x = i * (barWidth + gap);
      final y = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, height), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeluneMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
