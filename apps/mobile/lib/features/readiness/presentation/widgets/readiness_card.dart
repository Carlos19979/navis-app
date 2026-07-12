import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// Glanceable "ready to sail" card for the boat overview. Tapping opens the
/// full breakdown.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key, required this.boatId});

  final String boatId;

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
      loading: () => const NavisCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        final (color, icon) = visuals(r.status);
        final count = r.attention.length;
        final subtitle = count == 0
            ? l.readinessAllGood
            : l.readinessItemsNeedAttention(count);
        return NavisCard(
          onTap: () => context.push('/boats/$boatId/readiness'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimens.spaceXs),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel(l, r.status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.txtPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.txtSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${r.score}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '/100',
                    style: TextStyle(fontSize: 12, color: context.txtSecondary),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.txtSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
