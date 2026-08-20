import 'package:navis_mobile/l10n/app_localizations.dart';

/// The display name of a document type.
///
/// It used to be a *private static* on the form screen, which is why the
/// documents **list** showed «Insurance Rc» — snake_case run through a
/// title-caser — while the form for the same document said «Seguro RC». The
/// list is the screen people actually read.
///
/// The long tail of capitalised cases is deliberate: rows created before the
/// canonical type values were aligned still carry the old display names, and
/// they have to keep rendering.
String documentTypeLabel(AppLocalizations l, String type) => switch (type) {
      'itb' => l.docTypeItb,
      'insurance_rc' => l.docTypeInsuranceRc,
      'insurance_full' => l.docTypeInsuranceFull,
      'life_raft' => l.docTypeLifeRaft,
      'extinguisher' => l.docTypeFireExtinguisher,
      'flares' => l.docTypeFlares,
      'first_aid' => l.docTypeFirstAidKit,
      'medical_cert' => l.docTypeMedicalCertificate,
      'radio_cert' => l.docTypeRadioLicense,
      'navigation_license' => l.docTypeNavigationLicense,
      // Legacy rows created before the canonical alignment keep rendering
      // through the old display names.
      'Registration' => l.docTypeRegistration,
      'Insurance' => l.docTypeInsurance,
      'Inspection' => l.docTypeInspection,
      'License' => l.docTypeLicense,
      'Safety Certificate' => l.docTypeSafetyCertificate,
      'Radio License' => l.docTypeRadioLicense,
      'Pollution Certificate' => l.docTypePollutionCertificate,
      'Medical Certificate' => l.docTypeMedicalCertificate,
      'Life Raft' => l.docTypeLifeRaft,
      'Fire Extinguisher' => l.docTypeFireExtinguisher,
      'Flares' => l.docTypeFlares,
      'First Aid Kit' => l.docTypeFirstAidKit,
      'Fishing Permit' => l.docTypeFishingPermit,
      'Other' => l.other,
      'custom' => l.docTypeCustom,
      // Anything the switch does not know — a legacy row, or a type added
      // server-side before the app learned about it — is prettified rather
      // than printed raw. Dropping this is how «safety_certificate» would end
      // up on screen as itself.
      _ => _prettify(type),
    };

/// `safety_certificate` → `Safety Certificate`. Values that are already
/// readable pass through unchanged.
String _prettify(String type) => type
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');
