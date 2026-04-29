import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final TripStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TripStatus.completed:
        return _StartButton(onPressed: onStart);
      case TripStatus.recording:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GradientControlButton(
              icon: Icons.pause,
              label: 'Pause',
              gradient: AppColors.amberGradient,
              glowColor: AppColors.amber,
              onPressed: onPause,
            ),
            const SizedBox(width: 24),
            _GradientControlButton(
              icon: Icons.stop,
              label: 'Stop',
              gradient: AppColors.redGradient,
              glowColor: AppColors.red,
              onPressed: onStop,
            ),
          ],
        );
      case TripStatus.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GradientControlButton(
              icon: Icons.play_arrow,
              label: 'Resume',
              gradient: AppColors.greenGradient,
              glowColor: AppColors.green,
              onPressed: onResume,
            ),
            const SizedBox(width: 24),
            _GradientControlButton(
              icon: Icons.stop,
              label: 'Stop',
              gradient: AppColors.redGradient,
              glowColor: AppColors.red,
              onPressed: onStop,
            ),
          ],
        );
    }
  }
}

class _StartButton extends StatefulWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cyanGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(
                      alpha: 0.25 + (_pulseAnimation.value * 0.25),
                    ),
                    blurRadius: 20 + (_pulseAnimation.value * 12),
                    spreadRadius: 2 + (_pulseAnimation.value * 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 48,
                color: Colors.white,
                semanticLabel: 'Start recording',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GradientControlButton extends StatefulWidget {
  const _GradientControlButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final Color glowColor;
  final VoidCallback onPressed;

  @override
  State<_GradientControlButton> createState() =>
      _GradientControlButtonState();
}

class _GradientControlButtonState extends State<_GradientControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: widget.label,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _pressed ? 0.90 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.gradient,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
