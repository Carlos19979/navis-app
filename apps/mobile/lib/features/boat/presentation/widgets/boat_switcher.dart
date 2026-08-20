import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/features/boat/presentation/providers/active_boat_provider.dart';
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
          Icon(
            Icons.expand_more_rounded,
            size: Dimens.iconMd,
            color: context.inkMuted,
          ),
        ],
      ],
    );

    if (!canSwitch) return title;

    return Semantics(
      button: true,
      label: l.changeBoat,
      value: boat.name,
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
