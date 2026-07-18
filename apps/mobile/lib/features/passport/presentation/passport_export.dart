import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
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

  if (!ref.read(effectiveTierProvider).canExportPassport) {
    final ok = await showPaywall(context, ref, reason: l.paywallReasonPassport);
    if (!ok || !context.mounted) return;
  }

  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  ));
  var spinnerOpen = true;
  void closeSpinner() {
    if (spinnerOpen && context.mounted) {
      Navigator.of(context).pop();
      spinnerOpen = false;
    }
  }

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
    // Boat photo for the PDF header — also best-effort. The stored URL may
    // point at a private bucket, so it goes through the same signed-URL
    // exchange the app uses to display it; public URLs pass through.
    Uint8List? photoBytes;
    final photoUrl = boat.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final storage = ref.read(storageServiceProvider);
        final resolved = await storage.signedDocumentUrl(photoUrl) ?? photoUrl;
        final res = await Dio().get<List<int>>(
          resolved,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = res.data;
        if (data != null && data.isNotEmpty) {
          photoBytes = Uint8List.fromList(data);
        }
      } catch (_) {
        photoBytes = null;
      }
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
      boatPhotoBytes: photoBytes,
    );

    final dir = await getTemporaryDirectory();
    final safeName = boat.name.replaceAll(RegExp(r'[^\w]+'), '_');
    final file = File('${dir.path}/navis_passport_$safeName.pdf');
    await file.writeAsBytes(bytes);

    closeSpinner(); // dismiss before showing the system share sheet

    // iOS presents the share sheet as a popover and requires a non-zero
    // sharePositionOrigin (required on iPad; also enforced on iOS 26 iPhone).
    final origin =
        context.mounted ? (Offset.zero & MediaQuery.of(context).size) : null;
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${l.passportTitle} — ${boat.name}',
      sharePositionOrigin: origin,
    );
  } catch (_) {
    closeSpinner();
    if (context.mounted) {
      NavisSnackbar.error(context, l.passportExportFailed);
    }
  }
}
