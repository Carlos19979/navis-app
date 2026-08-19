import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

/// The start button floats bare over the map, so a soft dark shadow keeps its
/// white label legible on both light and dark tiles. Everything else lives
/// inside the glass dock, which supplies its own contrast.
const _labelShadows = [
  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
];

/// Lightened red for the discard row: [AppColors.red] itself only reaches ~2.9:1
/// against the red-tinted glass, this clears WCAG AA.
const _discardTint = Color(0xFFFF8E80);

class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.onCancel,
  });

  final TripStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (status) {
      case TripStatus.completed:
        return _StartButton(onPressed: onStart);
      case TripStatus.recording:
        return _dock(
          l,
          primary: _GradientControlButton(
            icon: Icons.pause,
            label: l.pauseTrip,
            gradient: AppColors.amberGradient,
            glowColor: AppColors.amber,
            onPressed: onPause,
          ),
          secondary: _GradientControlButton(
            icon: Icons.stop,
            label: l.stopTrip,
            gradient: AppColors.redGradient,
            glowColor: AppColors.red,
            onPressed: onStop,
          ),
        );
      case TripStatus.paused:
        return _dock(
          l,
          primary: _GradientControlButton(
            icon: Icons.play_arrow,
            label: l.resumeTrip,
            gradient: AppColors.greenGradient,
            glowColor: AppColors.green,
            onPressed: onResume,
          ),
          secondary: _GradientControlButton(
            icon: Icons.stop,
            label: l.stopTrip,
            gradient: AppColors.redGradient,
            glowColor: AppColors.red,
            onPressed: onStop,
          ),
        );
    }
  }

  /// One glass panel holds every in-trip action. Discard used to be a bare
  /// white `TextButton` floating on the tiles, which disappeared over light
  /// coastline and read as decoration next to two 72dp gradient circles. Inside
  /// the dock it gets a guaranteed backdrop, a 48dp target and a bordered
  /// destructive treatment: still clearly subordinate to pause/stop (outlined,
  /// not filled), but impossible to miss.
  Widget _dock(
    AppLocalizations l, {
    required Widget primary,
    required Widget secondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceLg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimens.radiusXxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Dimens.blurControls,
            sigmaY: Dimens.blurControls,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              Dimens.spaceLg,
              Dimens.spaceLg,
              Dimens.spaceLg,
              Dimens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(Dimens.radiusXxl),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    primary,
                    const SizedBox(width: Dimens.spaceXl),
                    secondary,
                  ],
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: Dimens.spaceLg),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.glassOverlay,
                  ),
                  const SizedBox(height: Dimens.spaceMd),
                  _DiscardButton(label: l.cancelTrip, onPressed: onCancel!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined destructive row. Outlined instead of filled so it never
/// competes with the stop button, red-tinted so it never reads as "confirm".
class _DiscardButton extends StatefulWidget {
  const _DiscardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_DiscardButton> createState() => _DiscardButtonState();
}

class _DiscardButtonState extends State<_DiscardButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: Dimens.minTouchTarget,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: _pressed ? 0.28 : 0.16),
              borderRadius: BorderRadius.circular(Dimens.radiusLg),
              border: Border.all(
                color: AppColors.red.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: Dimens.iconSm,
                  color: _discardTint,
                ),
                const SizedBox(width: Dimens.spaceSm),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _discardTint,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    )..repeat(
        // Bounded: this glow sits on top of the map, so every frame of it
        // repainted map tiles and invalidated the blurred overlays around it.
        // A few breaths point at the button; after that the static cyan glow
        // is enough.
        reverse: true,
        count: PulseBudget.reverseHalves(PulseBudget.urgent),
      );
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
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.cyanGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(
                        alpha: 0.25 + (_pulseAnimation.value * 0.25),
                      ),
                      blurRadius: 16 + (_pulseAnimation.value * 8),
                      spreadRadius: 2 + (_pulseAnimation.value * 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 36,
                  color: Colors.white,
                  semanticLabel: 'Start recording',
                ),
              );
            },
          ),
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
  State<_GradientControlButton> createState() => _GradientControlButtonState();
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
        const SizedBox(height: Dimens.spaceSm),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: _labelShadows,
              ),
        ),
      ],
    );
  }
}
