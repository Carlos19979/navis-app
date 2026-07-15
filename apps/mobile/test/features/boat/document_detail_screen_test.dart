// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/presentation/screens/document_detail_screen.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

import '../../helpers/helpers.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const documentId = 'doc-1';

  late _MockDocumentRepository mockRepo;

  setUp(() {
    mockRepo = _MockDocumentRepository();
  });

  Widget buildSubject({
    Document? document,
    Future<Document> Function()? fetch,
    RouteSpy? spy,
  }) {
    return buildRoutedTestApp(
      const DocumentDetailScreen(documentId: documentId),
      spy: spy,
      overrides: [
        documentProvider.overrideWith(
          (ref, id) => fetch != null ? fetch() : Future.value(document!),
        ),
        documentRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  /// Asserts the given badge label is shown and painted in [color] (the badge
  /// text style carries the tier color).
  void expectBadge(WidgetTester tester, String label, Color color) {
    final text = tester.widget<Text>(find.text(label));
    expect(text.style?.color, color);
  }

  group('DocumentDetailScreen async states', () {
    testWidgets('loading shows spinner', (tester) async {
      setPhoneSize(tester);
      final completer = Completer<Document>();
      await tester.pumpWidget(buildSubject(fetch: () => completer.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavisLoading), findsOneWidget);

      await drain(tester);
    });

    testWidgets('error shows error widget', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(fetch: () async => throw Exception('boom')),
      );
      await pumpScreen(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
    });
  });

  group('DocumentDetailScreen status tiers', () {
    testWidgets('expired document shows red Expired badge and overdue text',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(document: makeDocument(daysUntilExpiry: -5)),
      );
      await pumpScreen(tester);

      expectBadge(tester, 'Expired', AppColors.red);
      expect(find.text('5 days overdue'), findsOneWidget);

      // The expired badge loops a shimmer animation: dispose it explicitly.
      await drain(tester);
    });

    testWidgets('critical document shows red Critical badge', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(document: makeDocument(daysUntilExpiry: 5)),
      );
      await pumpScreen(tester);

      expectBadge(tester, 'Critical', AppColors.red);
      expect(find.text('5 days remaining'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('warning document shows amber Warning badge', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(document: makeDocument(daysUntilExpiry: 60)),
      );
      await pumpScreen(tester);

      expectBadge(tester, 'Warning', AppColors.amber);
      expect(find.text('60 days remaining'), findsOneWidget);
    });

    testWidgets('ok document shows green Valid badge', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(document: makeDocument(daysUntilExpiry: 120)),
      );
      await pumpScreen(tester);

      expectBadge(tester, 'Valid', AppColors.green);
      expect(find.text('120 days remaining'), findsOneWidget);
    });
  });

  group('DocumentDetailScreen renewal card', () {
    testWidgets('shows renewal card when lastRenewalDate is set',
        (tester) async {
      setPhoneSize(tester);
      final doc = makeDocument().copyWith(
        lastRenewalDate: DateTime(2026, 3),
        lastRenewalCost: 120.5,
        lastRenewalProvider: 'Marina Insurance SL',
      );
      await tester.pumpWidget(buildSubject(document: doc));
      await pumpScreen(tester);

      expect(find.text('Last Renewal'), findsOneWidget);
      expect(find.text('€120.50'), findsOneWidget);
      expect(find.text('Marina Insurance SL'), findsOneWidget);
    });

    testWidgets('hides renewal card when lastRenewalDate is absent',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(document: makeDocument()));
      await pumpScreen(tester);

      expect(find.text('Last Renewal'), findsNothing);
    });
  });

  group('DocumentDetailScreen actions', () {
    testWidgets('edit action navigates to the edit route', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(document: makeDocument(), spy: spy),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Edit Document'));
      await pumpScreen(tester);

      expect(spy.last, '/documents/doc-1/edit?boatId=boat-1');
    });

    testWidgets('renew action navigates to the edit route with renew flag',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(document: makeDocument(), spy: spy),
      );
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Renew Document'));
      await pumpScreen(tester);

      expect(spy.last, '/documents/doc-1/edit?boatId=boat-1&renew=true');
    });

    testWidgets('delete confirm calls repository and pops back',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.deleteDocument(documentId)).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject(document: makeDocument()));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Delete'));
      await pumpScreen(tester);

      expect(find.text('Delete Document'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await pumpScreen(tester);

      verify(() => mockRepo.deleteDocument(documentId)).called(1);
      expectSnackbar(tester, 'Document deleted');
      // context.pop() returned to the host page.
      expect(find.text('__host__'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('delete cancel keeps the document', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(document: makeDocument()));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Delete'));
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.deleteDocument(any()));
      expect(find.byType(DocumentDetailScreen), findsOneWidget);
    });
  });
}
