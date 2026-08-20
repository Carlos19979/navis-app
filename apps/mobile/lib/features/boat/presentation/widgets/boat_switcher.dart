import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/features/boat/presentation/providers/active_boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';

/// The boat's name as the screen's title, tappable when there is more than one.
///
/// Replaces going back to a list to change context. With a single boat — which
/// is most owners — it is just a title and there is nothing to discover.
class BoatSwitcher extends ConsumerWidget {
  const BoatSwitcher({super.key, required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final boats = ref.watch(allBoatsProvider);
    final canSwitch = boats.length > 1;
    final othersNeedAttention = canSwitch && _othersNeedAttention(ref, boats);

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            boat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NavisType.title2.copyWith(color: context.ink),
          ),
        ),
        if (canSwitch) ...[
          const SizedBox(width: Dimens.spaceXs),
          // A dot on the chevron when *another* boat has something pending.
          //
          // Without it, the only place that says so is the "My boats" section
          // near the bottom of the page: an owner of three boats had to scroll
          // past everything to find out that boat B's insurance had expired.
          // This keeps Today about one boat and still answers "does another one
          // need me?" without scrolling.
          Badge(
            isLabelVisible: othersNeedAttention,
            backgroundColor: context.caution,
            smallSize: 7,
            child: Icon(
              Icons.expand_more_rounded,
              size: Dimens.iconMd,
              color: context.inkMuted,
            ),
          ),
        ],
      ],
    );

    if (!canSwitch) return title;

    return Semantics(
      button: true,
      label: l.changeBoat,
      // Spoken, not just drawn: a dot is invisible to a screen reader.
      value: othersNeedAttention
          ? '${boat.name}, ${l.otherBoatsNeedAttention}'
          : boat.name,
      child: InkWell(
        onTap: () => _showPicker(context, ref, boats),
        borderRadius: BorderRadius.circular(Dimens.radiusChip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spaceXs),
          child: ExcludeSemantics(child: title),
        ),
      ),
    );
  }

  /// Whether any boat other than the active one has an alert.
  ///
  /// Reads the same document summary the rows below use, so the dot and the
  /// chips can never disagree.
  bool _othersNeedAttention(WidgetRef ref, List<Boat> boats) {
    for (final other in boats) {
      if (other.id == boat.id) continue;
      final summary =
          ref.watch(boatDocumentSummaryProvider(other.id)).valueOrNull;
      if (documentsTone(summary) != NavisTone.neutral) return true;
    }
    return false;
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<Boat> boats,
  ) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      // The sheet must clear the floating nav pill, which overlays the shell.
      useSafeArea: true,
      // Scroll-controlled and scrollable: owned boats top out at three, but
      // *shared* boats have no limit — crew on enough boats and a plain Column
      // overflowed the sheet's 9/16 height budget.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Dimens.spaceLg),
          child: NavisList(
            title: l.changeBoat,
            children: [
              for (final option in boats)
                NavisRow(
                  title: option.name,
                  subtitle: [
                    localizedBoatType(l, option.type),
                    if (option.homePort != null) option.homePort!,
                  ].join(' · '),
                  icon: option.id == boat.id
                      ? Icons.check_circle_rounded
                      : Icons.sailing_outlined,
                  iconColor: option.id == boat.id ? context.accent : null,
                  showChevron: false,
                  onTap: () {
                    ref.read(activeBoatIdProvider.notifier).select(option.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
