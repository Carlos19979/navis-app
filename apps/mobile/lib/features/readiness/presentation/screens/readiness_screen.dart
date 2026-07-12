import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class ReadinessScreen extends ConsumerWidget {
  const ReadinessScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatReadinessProvider(boatId));

    return NavisScaffold(
      title: l.readinessTitle,
      showBack: true,
      body: async.when(
        loading: () => const NavisShimmer(itemHeight: 96),
        error: (e, _) => NavisErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(boatReadinessProvider(boatId)),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(Dimens.spaceLg),
          children: [
            _Header(readiness: r),
            const SizedBox(height: Dimens.spaceLg),
            for (final c in r.categories) ...[
              _CategoryRow(category: c),
              const SizedBox(height: Dimens.spaceSm),
            ],
            if (r.attention.isNotEmpty) ...[
              const SizedBox(height: Dimens.spaceSm),
              Text(
                l.readinessNeedsAttention,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                ),
              ),
              const SizedBox(height: Dimens.spaceSm),
              for (final item in r.attention) ...[
                _AttentionRow(item: item),
                const SizedBox(height: Dimens.spaceSm),
              ],
            ],
            if (!r.full) ...[
              const SizedBox(height: Dimens.spaceSm),
              _UpsellCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.readiness});

  final Readiness readiness;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (color, icon) = ReadinessCard.visuals(readiness.status);
    return NavisCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: Dimens.spaceSm),
          Text(
            ReadinessCard.statusLabel(l, readiness.status),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.txtPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.readinessScoreOf(readiness.score),
            style: TextStyle(fontSize: 14, color: context.txtSecondary),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final ReadinessCategory category;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (color, icon) = ReadinessCard.visuals(category.status);
    final label = switch (category.key) {
      'documents' => l.readinessCatDocuments,
      'safety_gear' => l.readinessCatSafetyGear,
      'maintenance' => l.readinessCatMaintenance,
      _ => category.key,
    };
    return NavisCard(
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.txtPrimary,
              ),
            ),
          ),
          Text(
            l.readinessOkOfTotal(category.ok, category.total),
            style: TextStyle(fontSize: 13, color: context.txtSecondary),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final ReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = item.status == ReadinessStatus.notReady
        ? AppColors.red
        : AppColors.amber;
    return NavisCard(
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Text(
              _refLabel(l, item.ref),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.txtPrimary,
              ),
            ),
          ),
          Text(
            _daysLabel(l, item),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsellCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.cyan, size: 22),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Text(
              l.readinessUpgradeForFull,
              style: TextStyle(fontSize: 14, color: context.txtPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Localizes an attention item's ref (API document type, or "engine_service").
String _refLabel(AppLocalizations l, String ref) => switch (ref) {
      'itb' => l.readinessRefItb,
      'insurance_rc' => l.readinessRefInsurance,
      'insurance_full' => l.readinessRefInsurance,
      'life_raft' => l.readinessRefLifeRaft,
      'extinguisher' => l.readinessRefExtinguisher,
      'flares' => l.readinessRefFlares,
      'first_aid' => l.readinessRefFirstAid,
      'medical_cert' => l.readinessRefMedicalCert,
      'radio_cert' => l.readinessRefRadioCert,
      'navigation_license' => l.readinessRefNavLicense,
      'engine_service' => l.readinessRefEngineService,
      _ => l.readinessRefDocument,
    };

/// Human string for an item's timing.
String _daysLabel(AppLocalizations l, ReadinessItem item) {
  if (item.ref == 'engine_service') return l.readinessServiceOverdue;
  if (item.days < 0) return l.readinessExpired;
  return l.readinessExpiresInDays(item.days);
}
