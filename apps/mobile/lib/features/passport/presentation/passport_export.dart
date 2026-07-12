import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/passport/data/passport_pdf.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Gathers the boat's data, renders the passport PDF and opens the share sheet.
/// Gated behind Pro; shows the paywall for Free users first.
Future<void> exportBoatPassport(
  BuildContext context,
  WidgetRef ref,
  Boat boat,
) async {
  final l = AppLocalizations.of(context)!;

  if (!ref.read(isProProvider)) {
    final ok = await showPaywall(context, ref, reason: l.paywallReasonPassport);
    if (!ok || !context.mounted) return;
  }

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  ));

  try {
    // Each source is best-effort: a single failing fetch shouldn't abort the
    // whole export — the passport just includes what it could gather.
    List<Document> docs = const [];
    try {
      docs = await ref.read(boatDocumentsProvider(boat.id).future);
    } catch (_) {}
    List<MaintenanceLog> logs = const [];
    try {
      logs = await ref.read(maintenanceLogsProvider(boat.id).future);
    } catch (_) {}
    ExpenseSummary? expenses;
    try {
      expenses = await ref.read(expenseSummaryProvider(boat.id).future);
    } catch (_) {
      expenses = null;
    }

    final labels = PassportLabels(
      title: l.passportTitle,
      generatedOn: l.passportGeneratedOn,
      boatDetails: l.passportBoatDetails,
      registration: l.registration,
      type: l.boatType,
      length: l.length,
      homePort: l.homePort,
      documents: l.documents,
      expiry: l.expiryDate,
      status: l.status,
      maintenanceHistory: l.passportMaintenanceHistory,
      date: l.date,
      cost: l.cost,
      expensesSummary: l.passportExpensesSummary,
      total: l.total,
      none: l.passportNone,
      statusExpired: l.expired,
      statusCritical: l.critical,
      statusWarning: l.warning,
      statusOk: l.valid,
    );

    final bytes = await buildPassportPdf(
      boat: boat,
      documents: docs,
      maintenance: logs,
      expenses: expenses,
      labels: labels,
      generatedOnValue: NavisDateUtils.formatDate(DateTime.now()),
    );

    final dir = await getTemporaryDirectory();
    final safeName = boat.name.replaceAll(RegExp(r'[^\w]+'), '_');
    final file = File('${dir.path}/navis_passport_$safeName.pdf');
    await file.writeAsBytes(bytes);

    if (context.mounted) Navigator.of(context).pop(); // close spinner

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${l.passportTitle} — ${boat.name}',
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      NavisSnackbar.error(context, l.passportExportFailed);
    }
  }
}
