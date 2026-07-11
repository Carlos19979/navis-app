import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Motion tokens + a single entrance animation, so the ~59 scattered
/// `.animate().fadeIn().slideY()` call sites share one timing language.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve curve = Curves.easeOutCubic;

  /// Per-item stagger step for list entrances.
  static const Duration stagger = Duration(milliseconds: 60);
}

/// Standard staggered entrance: fade + subtle upward slide, delayed by [index].
/// Use on list items / stacked sections for a consistent feel.
extension NavisEntranceX on Widget {
  Widget entrance({int index = 0}) {
    return animate(delay: Motion.stagger * index)
        .fadeIn(duration: Motion.slow, curve: Motion.curve)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: Motion.slow,
          curve: Motion.curve,
        );
  }
}
