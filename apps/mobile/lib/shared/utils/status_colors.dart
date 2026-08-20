import 'package:flutter/widgets.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';

/// Maps a domain state to a semantic colour, in one place.
///
/// Each of these ladders used to be written out per screen, and they had already
/// drifted: the expiry ladder existed in four copies, one of which hard-coded
/// `daysLeft <= 30` while the others went through
/// [NavisDateUtils.expiryCriticalDays] — so the same document could show a
/// different colour in the list and on its own card. The trip-status map existed
/// twice, byte-identical, in the regattas and clubs features.
///
/// These return the **text-role** accents, because that is what a status is
/// almost always painted as: a label, a glyph, or a dot next to a label. For a
/// filled bar or a chart series use the `*Fill` getters directly.
extension StatusColorsX on BuildContext {
  /// Colour for a document's expiry state. The thresholds are
  /// [NavisDateUtils.statusFor]'s, never re-derived here.
  Color expiryColor(DateTime expiryDate) =>
      expiryStatusColor(NavisDateUtils.statusFor(expiryDate));

  Color expiryStatusColor(DocExpiryStatus status) => switch (status) {
        DocExpiryStatus.expired => critical,
        DocExpiryStatus.critical => critical,
        DocExpiryStatus.warning => caution,
        DocExpiryStatus.ok => positive,
      };

  /// Colour for a trip/regatta lifecycle status, as the API spells it.
  ///
  /// Unknown values fall back to muted ink rather than to an accent: a newer
  /// server can introduce a status this build has never heard of, and painting
  /// it green would be a claim we cannot back.
  Color tripStatusColor(String status) => switch (status) {
        'planned' => accent,
        'recording' => positive,
        'completed' => inkMuted,
        'cancelled' => critical,
        _ => inkMuted,
      };

  /// Colour for a GPS fix, by its accuracy in metres.
  Color gpsAccuracyColor(double? metres) {
    if (metres == null) return inkMuted;
    if (metres < 10) return positive;
    if (metres < 25) return caution;
    return critical;
  }

  /// Colour for wind speed in knots (calm → strong).
  Color windColor(double knots) {
    if (knots < 10) return positive;
    if (knots < 20) return caution;
    return critical;
  }

  /// Colour for wave height in metres (calm → rough).
  Color waveColor(double metres) {
    if (metres < 0.5) return positive;
    if (metres < 1.5) return accent;
    if (metres < 2.5) return caution;
    return critical;
  }

  /// Colour for a speed-over-ground track segment, in knots.
  Color speedColor(double knots) {
    if (knots < 3) return accent;
    if (knots < 6) return positive;
    if (knots < 12) return caution;
    return critical;
  }
}
