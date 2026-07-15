@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_list_screen.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  // Expiry dates are relative to today so the status colors and days-left
  // badges stay constant across runs. The printed expiry date (dd MMM yyyy)
  // therefore changes when baselines are regenerated on a different day —
  // acceptable for a local-only golden; regenerate with --update-goldens.
  final docs = [
    makeDocument(id: 'doc-ok'),
    makeDocument(
      id: 'doc-warning',
      type: 'Registration',
      status: 'warning',
      daysUntilExpiry: 60,
    ),
    makeDocument(
      id: 'doc-critical',
      type: 'Inspection',
      status: 'critical',
      daysUntilExpiry: 5,
    ),
    makeDocument(
      id: 'doc-expired',
      type: 'License',
      status: 'expired',
      daysUntilExpiry: -30,
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('document list — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const DocumentListScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          boatProvider.overrideWith((ref, id) async => makeBoat(id: id)),
          boatDocumentsProvider.overrideWith((ref, id) async => docs),
        ],
      );
      await expectLater(
        find.byType(DocumentListScreen),
        matchesGoldenFile(goldenPath('document_list', brightness)),
      );
    });
  }
}
