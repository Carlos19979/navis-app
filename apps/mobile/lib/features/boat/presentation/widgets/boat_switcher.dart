import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/palette.dart';
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
  const BoatSwitcher({
    super.key,
    required this.boat,
    this.onDark = false,
    this.onAddBoat,
    this.onJoinBoat,
  });

  final Boat boat;

  /// Drawn over the boat's photograph, so the name and chevron are on-dark.
  final bool onDark;

  /// The sheet is now the only place the other boats live, so it also carries
  /// the two ways to get one more.
  final VoidCallback? onAddBoat;
  final VoidCallback? onJoinBoat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final boats = ref.watch(allBoatsProvider);
    final hasOthers = boats.length > 1;
    // Opens whenever there is *anything* in the sheet — and since the sheet
    // now holds «add a boat» and «join a boat», that is almost always.
    //
    // Gating this on `boats.length > 1` is what briefly made adding a second
    // boat impossible: with one boat there was no chevron, so no sheet, so no
    // way to reach either action. Same shape of bug as joining with none.
    final canOpen = hasOthers || onAddBoat != null || onJoinBoat != null;
    final othersNeedAttention = hasOthers && _othersNeedAttention(ref, boats);

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            boat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NavisType.title2.copyWith(
              color: onDark ? Palette.onAccent : context.ink,
            ),
          ),
        ),
        if (canOpen) ...[
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
              color: onDark
                  ? Palette.onAccent.withValues(alpha: 0.8)
                  : context.inkMuted,
            ),
          ),
        ],
      ],
    );

    if (!canOpen) return title;

    return Semantics(
      button: true,
      label: hasOthers ? l.changeBoat : l.myBoats,
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
    final hasOthers = boats.length > 1;
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
            title: hasOthers ? l.changeBoat : l.myBoats,
            children: [
              if (hasOthers)
                for (final option in boats)
                  _BoatOption(
                    option: option,
                    isActive: option.id == boat.id,
                    onPick: () {
                      ref.read(activeBoatIdProvider.notifier).select(option.id);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              // The sheet is the only place the other boats live now, so the
              // two ways to get one more live here too — they used to be the
              // last rows of a "My boats" section that duplicated this list.
              if (onAddBoat != null)
                NavisRow(
                  title: l.addBoat,
                  icon: Icons.add_rounded,
                  iconColor: context.accent,
                  showChevron: false,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onAddBoat!();
                  },
                ),
              if (onJoinBoat != null)
                NavisRow(
                  title: l.joinBoat,
                  icon: Icons.group_add_outlined,
                  iconColor: context.accent,
                  showChevron: false,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onJoinBoat!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One boat in the picker, **with its status**.
///
/// The chip is what made the retired "My boats" section worth having: with three
/// boats you need to see which one wants something before you switch to it, not
/// after.
class _BoatOption extends ConsumerWidget {
  const _BoatOption({
    required this.option,
    required this.isActive,
    required this.onPick,
  });

  final Boat option;
  final bool isActive;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final summary =
        ref.watch(boatDocumentSummaryProvider(option.id)).valueOrNull;
    final tone = documentsTone(summary);

    return NavisRow(
      title: option.name,
      subtitle: [
        localizedBoatType(l, option.type),
        if (option.homePort != null) option.homePort!,
      ].join(' · '),
      icon: isActive ? Icons.check_circle_rounded : Icons.sailing_outlined,
      iconColor: isActive ? context.accent : null,
      value: tone == NavisTone.neutral ? null : documentsValue(l, summary),
      valueTone: tone,
      showChevron: false,
      onTap: onPick,
    );
  }
}
