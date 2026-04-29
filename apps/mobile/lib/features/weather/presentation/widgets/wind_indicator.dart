import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';

class WindIndicator extends StatelessWidget {
  const WindIndicator({
    super.key,
    required this.direction,
    required this.speed,
    this.size = 60,
  });

  final double direction;
  final double speed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glass circle background with animated rotation
        GlassContainer(
          borderRadius: size / 2,
          padding: EdgeInsets.zero,
          borderColor: AppColors.cyan.withValues(alpha: 0.25),
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedRotation(
              turns: direction / 360,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              child: CustomPaint(
                painter: _WindArrowPainter(
                  color: AppColors.cyan,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Speed text
        Text(
          '${speed.toStringAsFixed(0)} kt',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),

        // Cardinal direction in glass pill badge
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Text(
            _degreesToCardinal(direction),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
          ),
        ),
      ],
    );
  }

  String _degreesToCardinal(double degrees) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

class _WindArrowPainter extends CustomPainter {
  _WindArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw gradient compass circle
    final circlePaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.1),
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.1),
          color.withValues(alpha: 0.4),
        ],
      ).createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw arrow (always pointing up; rotation handled by AnimatedRotation)
    final arrowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.6)],
      ).createShader(
          Rect.fromCenter(center: center, width: 12, height: radius * 2))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius + 4)
      ..lineTo(center.dx - 6, center.dy + radius * 0.3)
      ..lineTo(center.dx, center.dy + radius * 0.15)
      ..lineTo(center.dx + 6, center.dy + radius * 0.3)
      ..close();

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(_WindArrowPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
