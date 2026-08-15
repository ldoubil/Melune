import 'package:flutter/material.dart';
import 'package:melune/theme/tokens.dart';

class TrackCover extends StatelessWidget {
  const TrackCover({
    super.key,
    required this.url,
    this.size = 44,
    this.radius = 10,
  });

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget child;
    if (url.isEmpty) {
      child = Icon(Icons.graphic_eq, color: tokens.colorBrand, size: size * 0.5);
    } else {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        headers: const {'Referer': 'https://www.bilibili.com'},
        errorBuilder: (_, _, _) => Icon(
          Icons.graphic_eq,
          color: tokens.colorBrand,
          size: size * 0.5,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.colorBrandHighlight,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
