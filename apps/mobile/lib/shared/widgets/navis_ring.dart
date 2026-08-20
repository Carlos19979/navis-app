import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/palette.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// A score out of a maximum, drawn as an arc with the figure inside it.
///
/// The readiness screen used to lead with a 40px amber warning triangle and the
/// words "72 / 100" underneath — an alarm where the answer belonged. A ring
/// reads as a gauge: the arc says how far along, the colour says how worried to
/// be, and the number is exact for anyone who wants it.
///
/// **Battery:** the sweep is a one-shot [TweenAnimationBuilder] — it animates
/// to the value once and stops. There is no controller on `repeat()` here, and
/// the painter sits behind a [RepaintBoundary] so the sweep cannot invalidate
/// anything drawn around it. Changing [value] re-runs the same bounded tween.
class NavisRing extends StatelessWidget {
  const NavisRing({
    super.key,
    required this.value,
    required this.color,
    this.max = 100,
    this.size = 96,
    this.strokeWidth = 8,
    this.caption,
    this.semanticLabel,
    this.inkColor,
    this.trackColor,
  });

  /// The score. Clamped into `0..max` so a server surprise cannot draw a ring
  /// that wraps around itself.
  final int value;
  final int max;

  /// Semantic accent for the arc and the figure (text role — this is a glyph
  /// as much as a shape).
  final Color color;

  final double size;
  final double strokeWidth;

  /// Small line under the figure, e.g. the maximum ("/ 100").
  final String? caption;

  final String? semanticLabel;

  /// Colour of the figure. Defaults to page ink; pass the on-dark ink when the
  /// ring is drawn over a photograph.
  final Color? inkColor;

  /// Colour of the unfilled arc. Defaults to the page hairline.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 1 : max;
    final fraction = (value / safeMax).clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel ?? '$value / $safeMax',
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: fraction),
            duration: Motion.slow,
            curve: Motion.curve,
            builder: (context, swept, _) {
              return CustomPaint(
                painter: _RingPainter(
                  fraction: swept,
                  color: color,
                  track: trackColor ?? context.hairline,
                  strokeWidth: strokeWidth,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value',
                        style: NavisType.display.copyWith(
                          color: inkColor ?? context.ink,
                          fontSize: size * 0.30,
                        ),
                      ),
                      if (caption != null)
                        Text(
                          caption!,
                          style: NavisType.caption.copyWith(
                            color: inkColor?.withValues(alpha: 0.75) ??
                                context.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (fraction <= 0) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // Starts at twelve o'clock and runs clockwise, which is how a gauge reads.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

/// [NavisRing] as it appears over a photograph: on-dark ink, a translucent
/// white track, and no caption — the disc it sits in is already small.
class NavisRingOnMedia extends StatelessWidget {
  const NavisRingOnMedia({
    super.key,
    required this.score,
    required this.color,
    this.size = 84,
  });

  final int score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return NavisRing(
      value: score,
      color: color,
      size: size,
      strokeWidth: 6,
      inkColor: Palette.onAccent,
      trackColor: Palette.onAccent.withValues(alpha: 0.28),
    );
  }
}
