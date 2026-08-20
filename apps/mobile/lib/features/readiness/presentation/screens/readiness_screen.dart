import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_ring.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/readiness_labels.dart';
import 'package:navis_mobile/features/readiness/presentation/readiness_links.dart';
import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
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
          padding: Insets.screenWithNav,
          children: [
            _Header(readiness: r),
            const SizedBox(height: Dimens.spaceXl),
            // No heading on this one: it repeated the screen's own title, and
            // the categories *are* the body of the screen.
            NavisList(
              padding: EdgeInsets.zero,
              children: [
                for (final c in r.categories)
                  _categoryRow(context, l, c, boatId),
              ],
            ),
            if (r.attention.isNotEmpty) ...[
              const SizedBox(height: Dimens.spaceXl),
              NavisList(
                title: l.readinessNeedsAttention,
                padding: EdgeInsets.zero,
                children: [
                  for (final item in r.attention)
                    _attentionRow(context, l, item, boatId),
                ],
              ),
            ],
            if (!r.full) ...[
              const SizedBox(height: Dimens.spaceXl),
              const _Upsell(),
            ],
          ],
        ),
      ),
    );
  }

  /// One category: how many of its items are in order, and the way in.
  Widget _categoryRow(
    BuildContext context,
    AppLocalizations l,
    ReadinessCategory c,
    String boatId,
  ) {
    final label = switch (c.key) {
      'documents' => l.readinessCatDocuments,
      'safety_gear' => l.readinessCatSafetyGear,
      'maintenance' => l.readinessCatMaintenance,
      _ => c.key,
    };
    final route = readinessRoute(boatId: boatId, category: c.key);
    return NavisRow(
      icon: Icons.circle,
      iconColor: context.toneAccent(_tone(c.status)),
      title: label,
      value: l.readinessOkOfTotal(c.ok, c.total),
      onTap: route == null ? null : () => context.push(route),
    );
  }

  /// One thing that needs doing. The status can be a whole sentence («set up a
  /// maintenance plan»), so it goes *under* the label: side by side, a long
  /// status left the label so little width that it broke mid-word.
  Widget _attentionRow(
    BuildContext context,
    AppLocalizations l,
    ReadinessItem item,
    String boatId,
  ) {
    final tone = item.status == ReadinessStatus.notReady
        ? NavisTone.critical
        : NavisTone.caution;
    final route = readinessRoute(
      boatId: boatId,
      category: item.category,
      ref: item.ref,
    );
    return NavisRow(
      icon: Icons.circle,
      iconColor: context.toneAccent(tone),
      title: readinessItemTitle(l, item),
      subtitle: readinessDaysLabel(l, item),
      onTap: route == null ? null : () => context.push(route),
    );
  }
}

/// The readiness status as a system tone.
NavisTone _tone(ReadinessStatus s) => switch (s) {
      ReadinessStatus.ready => NavisTone.positive,
      ReadinessStatus.attention => NavisTone.caution,
      ReadinessStatus.notReady => NavisTone.critical,
    };

/// The score, as a gauge.
///
/// It used to lead with a 44 px warning triangle and «Score 72 / 100» under it —
/// an alarm where the answer belonged. The ring says how far along at a glance,
/// its colour says how worried to be, and the figure is exact for whoever wants
/// it. One-shot sweep, so it costs nothing at rest.
class _Header extends StatelessWidget {
  const _Header({required this.readiness});

  final Readiness readiness;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tone = _tone(readiness.status);

    return Row(
      children: [
        NavisRing(
          value: readiness.score,
          color: context.toneAccent(tone),
          caption: '/ 100',
          semanticLabel: l.readinessScoreOf(readiness.score),
        ),
        const SizedBox(width: Dimens.spaceXl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ReadinessCard.statusLabel(l, readiness.status),
                style: NavisType.title1.copyWith(color: context.ink),
              ),
              const SizedBox(height: Dimens.spaceXs),
              Text(
                readiness.attention.isEmpty
                    ? l.readinessAllGood
                    : l.readinessItemsNeedAttention(readiness.attention.length),
                style: NavisType.bodySm.copyWith(color: context.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The full check is a paid feature; Free sees the documents block only.
class _Upsell extends StatelessWidget {
  const _Upsell();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Quiet, like every other paid marker since this redesign: a lock and
    // muted ink, not a coloured card competing with the things that are
    // actually wrong.
    return Row(
      children: [
        Icon(
          Icons.lock_outline_rounded,
          color: context.inkFaint,
          size: Dimens.iconMd,
        ),
        const SizedBox(width: Dimens.spaceMd),
        Expanded(
          child: Text(
            l.readinessUpgradeForFull,
            style: NavisType.bodySm.copyWith(color: context.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// Localizes an attention item's ref (API document type, or "engine_service").
