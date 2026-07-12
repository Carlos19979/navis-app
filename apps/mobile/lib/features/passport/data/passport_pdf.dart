import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';

/// Localized labels for the passport PDF, supplied by the caller so this stays
/// free of BuildContext.
class PassportLabels {
  const PassportLabels({
    required this.title,
    required this.generatedOn,
    required this.boatDetails,
    required this.registration,
    required this.type,
    required this.length,
    required this.homePort,
    required this.documents,
    required this.expiry,
    required this.status,
    required this.maintenanceHistory,
    required this.date,
    required this.cost,
    required this.expensesSummary,
    required this.total,
    required this.none,
    required this.statusExpired,
    required this.statusCritical,
    required this.statusWarning,
    required this.statusOk,
  });

  final String title;
  final String generatedOn;
  final String boatDetails;
  final String registration;
  final String type;
  final String length;
  final String homePort;
  final String documents;
  final String expiry;
  final String status;
  final String maintenanceHistory;
  final String date;
  final String cost;
  final String expensesSummary;
  final String total;
  final String none;
  final String statusExpired;
  final String statusCritical;
  final String statusWarning;
  final String statusOk;
}

const _navy = PdfColor.fromInt(0xFF1B2A4A);
const _cyan = PdfColor.fromInt(0xFF4DA8DA);

/// Builds the boat passport dossier as PDF bytes.
Future<Uint8List> buildPassportPdf({
  required Boat boat,
  required List<Document> documents,
  required List<MaintenanceLog> maintenance,
  required ExpenseSummary? expenses,
  required PassportLabels labels,
  required String generatedOnValue,
}) {
  final doc = pw.Document();

  String statusLabel(DateTime expiry) =>
      switch (NavisDateUtils.statusFor(expiry)) {
        DocExpiryStatus.expired => labels.statusExpired,
        DocExpiryStatus.critical => labels.statusCritical,
        DocExpiryStatus.warning => labels.statusWarning,
        DocExpiryStatus.ok => labels.statusOk,
      };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _header(boat, labels, generatedOnValue),
        pw.SizedBox(height: 20),
        _boatDetails(boat, labels),
        pw.SizedBox(height: 20),
        _section(labels.documents),
        if (documents.isEmpty)
          pw.Text(labels.none)
        else
          _table(
            headers: [labels.type, labels.expiry, labels.status],
            rows: [
              for (final d in documents)
                [
                  d.type,
                  NavisDateUtils.formatDate(d.expiryDate),
                  statusLabel(d.expiryDate),
                ],
            ],
          ),
        pw.SizedBox(height: 20),
        _section(labels.maintenanceHistory),
        if (maintenance.isEmpty)
          pw.Text(labels.none)
        else
          _table(
            headers: [labels.date, labels.type, labels.cost],
            rows: [
              for (final m in maintenance)
                [
                  NavisDateUtils.formatDate(m.performedAt),
                  m.type,
                  m.cost == null ? '—' : '${m.cost!.toStringAsFixed(0)} €',
                ],
            ],
          ),
        if (expenses != null && expenses.totals.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          _section(labels.expensesSummary),
          _table(
            headers: [labels.type, labels.total],
            rows: [
              for (final e in expenses.totals.entries)
                [e.key, '${e.value.toStringAsFixed(0)} €'],
              [labels.total, '${expenses.total.toStringAsFixed(0)} €'],
            ],
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(Boat boat, PassportLabels labels, String generatedOn) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            boat.name,
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          pw.Text('Navis',
              style: const pw.TextStyle(fontSize: 16, color: _cyan)),
        ],
      ),
      pw.Text(
        labels.title,
        style: const pw.TextStyle(fontSize: 14, color: _cyan),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        '${labels.generatedOn}: $generatedOn',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
      pw.Divider(color: _cyan),
    ],
  );
}

pw.Widget _boatDetails(Boat boat, PassportLabels labels) {
  final rows = <List<String>>[
    [labels.registration, boat.registration],
    [labels.type, boat.type],
    [labels.length, '${boat.lengthMeters} m'],
    if (boat.homePort != null) [labels.homePort, boat.homePort!],
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _section(labels.boatDetails),
      for (final r in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 140,
                child: pw.Text(
                  r[0],
                  style: const pw.TextStyle(color: PdfColors.grey700),
                ),
              ),
              pw.Text(r[1],
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _section(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: _navy,
      ),
    ),
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: _navy),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignment: pw.Alignment.centerLeft,
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
  );
}
