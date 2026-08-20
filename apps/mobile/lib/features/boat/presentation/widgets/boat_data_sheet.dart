import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_viewer.dart';

/// The boat's own reference data, and its photos.
///
/// A sheet rather than a block on Today: registration, type, length and home
/// port are four rows nobody reads daily, and they sat in the middle of the
/// page between the sections and the other boats. The registration in
/// particular is the number an owner gets asked for, so it has to be readable
/// *somewhere* without opening the edit form — just not in the way.
///
/// The gallery lives here too. It is a plan gate (`galleryLimit`), so it needs a
/// screen; as a 96px strip under the heading it competed with the readiness
/// ring for the first look.
Future<void> showBoatDataSheet(BuildContext context, Boat boat) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _BoatDataSheet(boat: boat),
  );
}

class _BoatDataSheet extends StatelessWidget {
  const _BoatDataSheet({required this.boat});

  final Boat boat;

  List<String> get _photos => [
        if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty) boat.photoUrl!,
        ...boat.photoUrls,
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final photos = _photos;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Dimens.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spaceLg),
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: Insets.gutter,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Dimens.spaceSm),
                    itemBuilder: (context, i) => NavisPhotoThumb(
                      url: photos[i],
                      size: 96,
                      onTap: () => showNavisPhotoViewer(
                        context,
                        urls: photos,
                        initialIndex: i,
                      ),
                    ),
                  ),
                ),
              ),
            NavisList(
              title: l.boatData,
              children: [
                NavisRow(
                  title: l.registration,
                  value: boat.registration,
                  dense: true,
                  showChevron: false,
                ),
                NavisRow(
                  title: l.boatType,
                  value: localizedBoatType(l, boat.type),
                  dense: true,
                  showChevron: false,
                ),
                NavisRow(
                  title: l.length,
                  // Localised: `'${boat.lengthMeters} m'` printed "12.5 m" with
                  // a decimal point in a Spanish app.
                  value: Measure.metres(locale, boat.lengthMeters),
                  dense: true,
                  showChevron: false,
                ),
                if (boat.homePort != null)
                  NavisRow(
                    title: l.homePort,
                    value: boat.homePort!,
                    dense: true,
                    showChevron: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
