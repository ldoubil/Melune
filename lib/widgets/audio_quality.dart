import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

const kBiliVipPink = Color(0xFFFB7299);

class AudioQualityButton extends StatelessWidget {
  const AudioQualityButton({super.key, required this.player});

  final PlaybackStore player;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final quality = player.currentQuality;
    final accent = quality != null && (quality.isHiRes || quality.vipOnly)
        ? kBiliVipPink
        : tokens.colorBase;
    return IconButton(
      key: const Key('playback-quality'),
      tooltip: quality?.label ?? '音质',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: () => showAudioQualitySheet(context, player),
      icon: quality?.isHiRes == true
          ? const HiResWavesIcon(color: kBiliVipPink, size: 16)
          : Icon(Icons.high_quality_outlined, size: 20, color: accent),
    );
  }
}

Future<void> showAudioQualitySheet(
  BuildContext context,
  PlaybackStore player,
) async {
  if (player.qualities.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('播放后可切换音质，大会员稿件会给出 Hi-Res 无损')),
    );
    return;
  }
  final tokens = context.tokens;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black38,
    builder: (context) {
      return Dialog(
        backgroundColor: tokens.colorRaisedBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final current = player.currentQuality;
            final headline = current == null
                ? '音质'
                : current.label.endsWith('音质')
                    ? current.label
                    : '${current.label}音质';
            final accent = current != null &&
                    (current.isHiRes || current.vipOnly)
                ? kBiliVipPink
                : tokens.colorContrast;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (current?.isHiRes == true) ...[
                        HiResWavesIcon(color: accent, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Text(
                          headline,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      if (current?.vipOnly == true) ...[
                        const SizedBox(width: 8),
                        const VipBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final item in player.qualities)
                        InkWell(
                          key: Key('audio-quality-${item.id}'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: player.loading
                              ? null
                              : () {
                                  player.setQuality(item.id);
                                  Navigator.of(context).pop();
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.isHiRes) ...[
                                  HiResWavesIcon(
                                    color: item.id == player.selectedQualityId
                                        ? kBiliVipPink
                                        : tokens.colorBase,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: item.id == player.selectedQualityId
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: item.id == player.selectedQualityId
                                        ? (item.isHiRes || item.vipOnly
                                            ? kBiliVipPink
                                            : tokens.colorBrand)
                                        : tokens.colorBase,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class VipBadge extends StatelessWidget {
  const VipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: kBiliVipPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '大会员',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.4,
        ),
      ),
    );
  }
}

class HiResWavesIcon extends StatelessWidget {
  const HiResWavesIcon({super.key, this.color = kBiliVipPink, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HiResWavesPainter(color)),
    );
  }
}

class _HiResWavesPainter extends CustomPainter {
  const _HiResWavesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.1)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.22 + i * 0.28);
      final amp = size.width * (i == 1 ? 0.12 : 0.08);
      final path = Path();
      for (var p = 0; p <= 12; p++) {
        final t = p / 12;
        final y = size.height * t;
        final dx = x + amp * math.sin(t * math.pi * 2.2 + i * 0.9);
        if (p == 0) {
          path.moveTo(dx, y);
        } else {
          path.lineTo(dx, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HiResWavesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
