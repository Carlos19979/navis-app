import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/readiness_links.dart';
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
              _CategoryRow(category: c, boatId: boatId),
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
                _AttentionRow(item: item, boatId: boatId),
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
  const _CategoryRow({required this.category, required this.boatId});

  final ReadinessCategory category;
  final String boatId;

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
    final route = readinessRoute(boatId: boatId, category: category.key);
    return _RowCard(
      route: route,
      leading: Icon(icon, color: color, size: Dimens.iconMd),
      title: label,
      // Short trailing text ("2/3 OK"): it stays on the same line, and the
      // title keeps whatever is left instead of being squeezed.
      trailing: Text(
        l.readinessOkOfTotal(category.ok, category.total),
        style: TextStyle(fontSize: 13, color: context.txtSecondary),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.boatId});

  final ReadinessItem item;
  final String boatId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = item.status == ReadinessStatus.notReady
        ? AppColors.red
        : AppColors.amber;
    final route = readinessRoute(
      boatId: boatId,
      category: item.category,
      ref: item.ref,
    );
    // The status text can be a whole sentence ("set up a maintenance plan"), so
    // it goes UNDER the label instead of competing with it for the same line:
    // side by side, a long status left the label so little width that it broke
    // mid-word ("Mainten/ance").
    return _RowCard(
      route: route,
      borderColor: color.withValues(alpha: 0.4),
      leading: Icon(Icons.circle, color: color, size: 10),
      title: item.label.isNotEmpty ? item.label : _refLabel(l, item.ref),
      subtitle: Text(
        _daysLabel(l, item),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// One readiness line: leading dot/icon, a title that always gets the width it
/// needs, an optional subtitle under it, and an optional short trailing widget.
/// When [route] is non-null the whole card opens it.
class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.route,
    this.borderColor,
  });

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final String? route;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    final card = NavisCard(
      borderColor: borderColor,
      onTap: route == null ? null : () => context.push(route),
      child: Row(
        children: [
          leading,
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.txtPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Dimens.spaceSm),
            trailing!,
          ],
          if (route != null) ...[
            const SizedBox(width: Dimens.spaceXs),
            Icon(
              Icons.chevron_right_rounded,
              color: context.txtSecondary,
              size: Dimens.iconMd,
            ),
          ],
        ],
      ),
    );
    return route == null ? card : Semantics(button: true, child: card);
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
  if (item.ref == 'engine_service') {
    switch (item.reason) {
      case 'no_plan':
        return l.readinessMaintNoPlan;
      case 'overdue':
        return l.readinessMaintOverdue;
      case 'pending':
        return l.readinessMaintPending;
      default:
        // due_soon: prefer the nearer of date/hours.
        if (item.hours != null && (item.days <= 0 || item.hours! < item.days)) {
          return l.readinessMaintInHours(item.hours!.round());
        }
        return l.readinessExpiresInDays(item.days);
    }
  }
  if (item.days < 0) return l.readinessExpired;
  return l.readinessExpiresInDays(item.days);
}
