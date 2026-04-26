import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

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
    )..repeat();
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Padding(
          padding: widget.padding,
          child: Column(
            children: List.generate(
              widget.itemCount,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ShimmerCard(
                  height: widget.itemHeight,
                  shimmerValue: _animation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({
    required this.height,
    required this.shimmerValue,
  });

  final double height;
  final double shimmerValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment(shimmerValue - 1, 0),
          end: Alignment(shimmerValue, 0),
          colors: const [
            AppColors.darkCard,
            AppColors.darkDivider,
            AppColors.darkCard,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.darkDivider,
              borderRadius: BorderRadius.circular(8),
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
                    color: AppColors.darkDivider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.darkDivider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
