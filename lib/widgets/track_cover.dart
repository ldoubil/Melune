import 'dart:io';

import 'package:flutter/material.dart';
import 'package:melune/player/cover_cache.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/melune_mark.dart';
import 'package:melune/widgets/skeleton.dart';

class TrackCover extends StatefulWidget {
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
  State<TrackCover> createState() => _TrackCoverState();
}

class _TrackCoverState extends State<TrackCover> {
  File? _file;
  var _loading = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    CoverCache.instance.addListener(_onCache);
    _sync();
  }

  @override
  void dispose() {
    CoverCache.instance.removeListener(_onCache);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrackCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _sync(rebuild: true);
    }
  }

  void _onCache() {
    if (!mounted) {
      return;
    }
    final hit = CoverCache.instance.existing(widget.url);
    if (hit == null) {
      if (widget.url.isEmpty || _loading) {
        return;
      }
      _sync(rebuild: true);
      return;
    }
    if (_file?.path == hit.path && !_loading && !_failed) {
      return;
    }
    setState(() {
      _file = hit;
      _loading = false;
      _failed = false;
    });
  }

  void _sync({bool rebuild = false}) {
    final url = widget.url;
    File? file;
    var loading = false;
    var failed = false;
    if (url.isNotEmpty) {
      final hit = CoverCache.instance.existing(url);
      if (hit != null) {
        file = hit;
      } else {
        loading = true;
        CoverCache.instance.ensure(url).then((downloaded) {
          if (!mounted || widget.url != url) {
            return;
          }
          setState(() {
            _file = downloaded;
            _loading = false;
            _failed = downloaded == null;
          });
        });
      }
    }
    if (rebuild) {
      setState(() {
        _file = file;
        _loading = loading;
        _failed = failed;
      });
      return;
    }
    _file = file;
    _loading = loading;
    _failed = failed;
  }

  Widget _icon(Color color, double iconSize) {
    return widget.fallback ?? MeluneMark(size: iconSize, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;
    final expands = w == double.infinity || h == double.infinity;
    final iconSize = (expands ? widget.size : (w < h ? w : h)) * 0.42;
    final Widget child;
    if (_loading) {
      child = MeluneSkeleton(
        width: expands ? null : w,
        height: expands ? null : h,
        radius: 0,
      );
    } else if (_file != null) {
      child = Image.file(
        _file!,
        fit: BoxFit.cover,
        width: expands ? null : w,
        height: expands ? null : h,
        errorBuilder: (_, _, _) => _icon(tokens.colorBrand, iconSize),
      );
    } else if (widget.url.isEmpty || _failed) {
      child = _icon(tokens.colorBrand, iconSize);
    } else {
      child = MeluneSkeleton(
        width: expands ? null : w,
        height: expands ? null : h,
        radius: 0,
      );
    }
    final box = Container(
      width: expands ? null : w,
      height: expands ? null : h,
      decoration: BoxDecoration(
        color: tokens.colorBrandHighlight,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: expands ? SizedBox.expand(child: child) : child,
    );
    return expands ? SizedBox.expand(child: box) : box;
  }
}
