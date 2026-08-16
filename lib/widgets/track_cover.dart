import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:melune/player/cover_fetch.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/melune_mark.dart';
import 'package:melune/widgets/skeleton.dart';

class TrackCover extends StatelessWidget {
  const TrackCover({
    super.key,
    required this.url,
    this.size = 44,
    this.width,
    this.height,
    this.radius = 10,
    this.fallback,
  });

  final String url;
  final double size;
  final double? width;
  final double? height;
  final double radius;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final w = width ?? size;
    final h = height ?? size;
    final expands = w == double.infinity || h == double.infinity;
    final iconSize = (expands ? size : (w < h ? w : h)) * 0.42;
    final src = normalizeCoverUrl(url);
    final Widget child;
    if (src.isEmpty) {
      child = fallback ?? MeluneMark(size: iconSize, color: tokens.colorBrand);
    } else {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
      final cachePx = expands
          ? (size * dpr).round().clamp(64, 720)
          : ((w < h ? w : h) * dpr).round().clamp(48, 720);
      child = Image.network(
        src,
        headers: kIsWeb ? null : coverImageHeaders(),
        fit: BoxFit.cover,
        width: expands ? null : w,
        height: expands ? null : h,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        loadingBuilder: (context, image, progress) {
          if (progress == null) {
            return image;
          }
          return MeluneSkeleton(
            width: expands ? null : w,
            height: expands ? null : h,
            radius: 0,
          );
        },
        errorBuilder: (_, _, _) {
          return fallback ?? MeluneMark(size: iconSize, color: tokens.colorBrand);
        },
      );
    }
    final box = Container(
      width: expands ? null : w,
      height: expands ? null : h,
      decoration: BoxDecoration(
        color: tokens.colorBrandHighlight,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: expands ? SizedBox.expand(child: child) : child,
    );
    return expands ? SizedBox.expand(child: box) : box;
  }
}
