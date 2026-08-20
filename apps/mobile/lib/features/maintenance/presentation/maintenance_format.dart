import 'package:navis_mobile/l10n/app_localizations.dart';

/// The bits of formatting and parsing both the maintenance plan and the
/// expense ledger need.
///
/// They used to be private top-level functions in a 1.700-line screen that
/// held both. Splitting that screen into two routes made them shared, and a
/// shared thing with a leading underscore is a copy waiting to happen.
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Empty (or unparseable) input means "not set" — null, never zero, so an
/// interval or a cost the user left blank is cleared server-side.
int? parseInt(String s) => int.tryParse(s.trim());

double? parseDouble(String s) => double.tryParse(s.trim());

/// Maps an expense category API value to its localized display label.
String categoryLabel(AppLocalizations l, String category) => switch (category) {
      'combustible' => l.expenseCategoryFuel,
      'amarre' => l.expenseCategoryMooring,
      'seguro' => l.expenseCategoryInsurance,
      'reparación' => l.expenseCategoryRepair, // i18n-exempt: API value
      'limpieza' => l.expenseCategoryCleaning,
      'otros' => l.expenseCategoryOther,
      _ => category,
    };
