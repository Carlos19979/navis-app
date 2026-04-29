import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class NavisShimmer extends StatefulWidget {
  const NavisShimmer({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 88,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      CurvedAnimation(
          parent: _controller, curve: Curves.easeInOutSine),
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
                child: _ShimmerItem(
                  height: widget.itemHeight,
                  animationValue: _animation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerItem extends StatelessWidget {
  const _ShimmerItem({
    required this.height,
    required this.animationValue,
  });

  final double height;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment(animationValue - 1, 0),
          end: Alignment(animationValue, 0),
          colors: const [
            AppColors.glassWhite,
            AppColors.glassHighlight,
            AppColors.glassWhite,
          ],
        ),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
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
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 10,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.glassWhite,
                    borderRadius: BorderRadius.circular(6),
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
