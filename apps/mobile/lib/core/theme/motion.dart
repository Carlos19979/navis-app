import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Motion tokens, so the 68 scattered `.animate().fadeIn().slideY()` call sites
/// share one timing language.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve curve = Curves.easeOutCubic;

  /// Per-item stagger step for list entrances.
  static const Duration stagger = Duration(milliseconds: 40);

  /// The stagger stops accumulating after this many items.
  ///
  /// Without a cap the delay grows without bound: the logbook used
  /// `100ms * index`, so the thirty-first trip waited three seconds before
  /// appearing, and a scroll to item 60 met a blank list. Past this point every
  /// remaining item enters together, which is imperceptible and keeps the
  /// animation budget flat regardless of list length.
  static const int maxStaggerIndex = 8;
}

/// Standard staggered entrance: fade + a short upward slide, delayed by
/// [index] (capped at [Motion.maxStaggerIndex]).
///
/// Bounded by construction — a fixed duration with no `repeat()` — which is
/// what keeps it inside the battery contract. Use this instead of hand-rolling
/// `.animate().fadeIn(...)`, so there is exactly one place where the app's
/// entrance timing lives.
extension NavisEntranceX on Widget {
  Widget entrance({int index = 0}) {
    final step = index.clamp(0, Motion.maxStaggerIndex);
    return animate(delay: Motion.stagger * step)
        .fadeIn(duration: Motion.slow, curve: Motion.curve)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: Motion.slow,
          curve: Motion.curve,
        );
  }
}
