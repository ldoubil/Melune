import 'package:flutter/material.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

class VolumeButton extends StatelessWidget {
  const VolumeButton({super.key, required this.player, this.iconSize = 20});

  final PlaybackStore player;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MenuAnchor(
      alignmentOffset: const Offset(-100, 4),
      builder: (context, controller, _) {
        return IconButton(
          tooltip: '音量',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(
            player.volume <= 0
                ? Icons.volume_off_rounded
                : player.volume < 0.4
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: iconSize,
            color: tokens.colorBase,
          ),
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          child: SizedBox(
            width: 140,
            child: ListenableBuilder(
              listenable: player,
              builder: (context, _) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: tokens.colorBrand,
                    inactiveTrackColor: tokens.colorBrand.withValues(alpha: 0.22),
                    thumbColor: tokens.colorBrand,
                  ),
                  child: Slider(
                    value: player.volume,
                    onChanged: player.setVolume,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
