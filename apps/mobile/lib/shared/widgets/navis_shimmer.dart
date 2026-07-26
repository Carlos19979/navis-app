import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

/// List skeleton with a travelling highlight.
///
/// The loop stops the moment the data arrives, because the caller replaces
/// this widget with the loaded list; [PulseBudget.loadingStall] only bounds
/// the case of a request that never comes back. Per frame the only thing
/// rebuilt is the sweeping gradient of each row — the skeleton bars inside are
/// built once and handed to [AnimatedBuilder] as its `child` — and the whole
/// group sits behind a [RepaintBoundary] so it does not invalidate the blurred
/// app bar or nav bar above it.
class NavisShimmer extends StatefulWidget {
  const NavisShimmer({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 88,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  State<NavisShimmer> createState() => _NavisShimmerState();
}

class _NavisShimmerState extends State<NavisShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(count: PulseBudget.loadingStall);
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: widget.padding,
        child: Column(
          children: List.generate(
            widget.itemCount,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShimmerItem(
                height: widget.itemHeight,
                animation: _animation,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerItem extends StatelessWidget {
  const _ShimmerItem({
    required this.height,
    required this.animation,
  });

  final double height;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // Static skeleton: built once per layout, reused every frame.
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.glassBg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.glassBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: context.glassBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (context, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(animation.value - 1, 0),
              end: Alignment(animation.value, 0),
              colors: [
                context.glassBg,
                AppColors.glassHighlight,
                context.glassBg,
              ],
            ),
            border: Border.all(
              color: context.glassBorderColor,
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        );
      },
    );
  }
}
