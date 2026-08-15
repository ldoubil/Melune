import 'package:flutter/material.dart';
import 'package:melune/pages/playlist_page.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/playback_bar.dart';

class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    required this.wide,
  });

  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = wide
        ? const BorderRadius.only(topLeft: Radius.circular(20))
        : const BorderRadius.all(Radius.circular(20));
    final media = MediaQuery.of(context);
    final overlay = PlaybackBar.overlayExtent();

    return Expanded(
      child: Material(
        color: tokens.colorBg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.colorDivider),
        ),
        child: Stack(
          children: [
            MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(
                  bottom: media.padding.bottom + overlay,
                ),
              ),
              child: child,
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PlaybackBar(),
            ),
            const Positioned.fill(child: PlaylistGate()),
          ],
        ),
      ),
    );
  }
}
