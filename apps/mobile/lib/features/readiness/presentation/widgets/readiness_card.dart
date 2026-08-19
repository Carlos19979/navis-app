import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// Glanceable "ready to sail" banner for the boat detail. Tapping opens the
/// full breakdown.
///
/// Deliberately NOT a [NavisCard]: it used to be one, sitting in a stack of
/// glass action tiles that look exactly the same, and it read as one more row
/// to tap through instead of the boat's headline status. It now carries the
/// status colour as its own surface and a score dial, so it is the one thing
/// on the screen that is not a list row. It also no longer appears on the boat
/// list — one boat's status does not belong in a list of boats.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key, required this.boatId});

  final String boatId;

  /// Height of the score dial. Also the banner's floor, so the loading and
  /// loaded states are the same size and the screen does not jump.
  static const _dialSize = 58.0;

  static (Color, IconData) visuals(ReadinessStatus s) => switch (s) {
        ReadinessStatus.ready => (AppColors.green, Icons.check_circle_rounded),
        ReadinessStatus.attention => (AppColors.amber, Icons.warning_rounded),
        ReadinessStatus.notReady => (AppColors.red, Icons.error_rounded),
      };

  static String statusLabel(AppLocalizations l, ReadinessStatus s) =>
      switch (s) {
        ReadinessStatus.ready => l.readinessReady,
        ReadinessStatus.attention => l.readinessAttention,
        ReadinessStatus.notReady => l.readinessNotReady,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatReadinessProvider(boatId));

    return async.when(
      loading: () => _Shell(
        color: context.txtSecondary,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        final (color, icon) = visuals(r.status);
        final count = r.attention.length;
        final subtitle = count == 0
            ? l.readinessAllGood
            : l.readinessItemsNeedAttention(count);
        void open() => context.push('/boats/$boatId/readiness');
        return Semantics(
          button: true,
          // One label for the whole banner, and the tap action re-declared on
          // it: the parts (an uppercase eyebrow, a bare "/100") read as noise
          // one by one.
          label: '${l.readinessTitle}: ${statusLabel(l, r.status)}, '
              '${l.readinessScoreOf(r.score)}. $subtitle',
          onTap: open,
          child: ExcludeSemantics(
            child: _Shell(
              color: color,
              onTap: open,
              child: Row(
                children: [
                  _ScoreDial(score: r.score, color: color),
                  const SizedBox(width: Dimens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.readinessTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: context.txtSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(icon, color: color, size: Dimens.iconSm),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                statusLabel(l, r.status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.txtPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.txtSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.txtSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The status-tinted surface both states share.
class _Shell extends StatelessWidget {
  const _Shell({required this.color, required this.child, this.onTap});

  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Dimens.radiusXxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.radiusXxl),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ReadinessCard._dialSize + Dimens.spaceLg * 2,
          ),
          padding: const EdgeInsets.all(Dimens.spaceLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimens.radiusXxl),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Score as a dial rather than a number in a corner: the fill is readable
/// before the digits are, which is the whole point of a glance.
class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size.square(ReadinessCard._dialSize),
        painter: _DialPainter(
          progress: (score / 100).clamp(0.0, 1.0),
          color: color,
          trackColor: color.withValues(alpha: 0.22),
        ),
        child: SizedBox.square(
          dimension: ReadinessCard._dialSize,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: color,
                  ),
                ),
                Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.3,
                    color: context.txtSecondary,
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

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const _stroke = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - _stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
