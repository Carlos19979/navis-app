import 'package:navis_mobile/l10n/app_localizations.dart';

/// Localized display label for a boat type. Shared by the dashboard, detail
/// and form screens (was copied verbatim in all three).
String localizedBoatType(AppLocalizations l, String type) => switch (type) {
      'sailboat' => l.sailboat,
      'motorboat' => l.motorboat,
      'catamaran' => l.catamaran,
      'other' => l.other,
      _ => type.isEmpty ? type : type[0].toUpperCase() + type.substring(1),
    };
