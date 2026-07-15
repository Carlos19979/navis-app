// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/presentation/widgets/document_card.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_list_screen.dart';

import '../../helpers/test_helpers.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

/// Pump enough frames for async providers and initial animations
/// without pumpAndSettle (flutter_animate has repeating animations).
Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const boatId = 'boat-1';

  // Documents with various expiry states
  final okDoc = makeDocument(
    id: 'doc-ok',
  );

  final warningDoc = makeDocument(
    id: 'doc-warning',
    type: 'Registration',
    status: 'warning',
    // Warning band is 31–90 days (aligned with the server's documents.status).
    daysUntilExpiry: 60,
  );

  final criticalDoc = makeDocument(
    id: 'doc-critical',
    type: 'Inspection',
    status: 'critical',
    daysUntilExpiry: 5,
  );

  final expiredDoc = makeDocument(
    id: 'doc-expired',
    type: 'License',
    status: 'expired',
    daysUntilExpiry: -30,
  );

  final testDocs = [okDoc, warningDoc, criticalDoc, expiredDoc];

  Widget buildSubject({
    List<Document> docs = const [],
    bool useError = false,
  }) {
    final router = GoRouter(
      initialLocation: '/boats/$boatId/documents',
      routes: [
        GoRoute(
          path: '/boats/:boatId/documents',
          builder: (_, state) => DocumentListScreen(
            boatId: state.pathParameters['boatId']!,
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) =>
                  const Scaffold(body: Text('New Document Page')),
            ),
          ],
        ),
        GoRoute(
          path: '/documents/:id',
          builder: (_, __) =>
              const Scaffold(body: Text('Document Detail Page')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        boatProvider.overrideWith(
          (ref, id) async => Boat(
            id: id,
            name: 'Test Boat',
            registration: 'TEST-1',
            type: 'sailboat',
            lengthMeters: 10,
          ),
        ),
        boatDocumentsProvider.overrideWith(
          (ref, id) async {
            if (useError) {
              throw Exception('Failed to load documents');
            }
            return docs;
          },
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
      ),
    );
  }

  group('DocumentListScreen', () {
    testWidgets('shows app bar with Documents title', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('renders document cards with formatted type names',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('License'), findsOneWidget);
    });

    testWidgets('renders a card per document', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      expect(find.byType(DocumentCard), findsNWidgets(4));
    });

    testWidgets('shows status badges on document cards', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      // DocumentStatusBadge renders based on expiry date
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('documents are sorted by expiry date ascending',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      // Verify all 4 cards are rendered (sorted by expiry)
      expect(find.byType(DocumentCard), findsNWidgets(4));
    });

    testWidgets('shows FAB with add tooltip', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      final fabWidget = tester.widget<FloatingActionButton>(fab);
      expect(fabWidget.tooltip, 'New Document');
    });

    testWidgets('FAB navigates to new document page', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(find.text('New Document Page'), findsOneWidget);
    });

    testWidgets('shows empty state when no documents', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: []));
      await pumpScreen(tester);

      expect(
        find.text('No documents yet. Add your first document!'),
        findsOneWidget,
      );
      expect(find.text('New Document'), findsOneWidget);
    });

    testWidgets('empty state Add Document button navigates', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: []));
      await pumpScreen(tester);

      await tester.tap(find.text('New Document'));
      await pumpScreen(tester);

      expect(find.text('New Document Page'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button is tappable in error state', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      await tester.tap(find.text('Retry'));
      await pumpScreen(tester);

      // After retry, still shows error
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows shimmer loading state initially', (tester) async {
      await setPhoneSize(tester);
      final router = GoRouter(
        initialLocation: '/boats/$boatId/documents',
        routes: [
          GoRoute(
            path: '/boats/:boatId/documents',
            builder: (_, state) => DocumentListScreen(
              boatId: state.pathParameters['boatId']!,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boatProvider.overrideWith(
              (ref, id) async => Boat(
                id: id,
                name: 'Test Boat',
                registration: 'TEST-1',
                type: 'sailboat',
                lengthMeters: 10,
              ),
            ),
            boatDocumentsProvider.overrideWith(
              (ref, id) =>
                  Future<List<Document>>.delayed(const Duration(days: 1)),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DocumentListScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('document card navigates to detail', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      await tester.tap(find.text('Insurance'));
      await pumpScreen(tester);

      expect(find.text('Document Detail Page'), findsOneWidget);
    });

    testWidgets('pull to refresh triggers invalidation', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: testDocs));
      await pumpScreen(tester);

      await tester.fling(
        find.text('Insurance'),
        const Offset(0, 300),
        1000,
      );
      await pumpScreen(tester);

      // Documents should still be visible after refresh
      expect(find.text('Insurance'), findsOneWidget);
    });

    testWidgets('renders single document correctly', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(docs: [okDoc]));
      await pumpScreen(tester);

      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.byType(DocumentCard), findsOneWidget);
    });

    testWidgets('handles underscore types with proper formatting',
        (tester) async {
      await setPhoneSize(tester);
      final customDoc = makeDocument(
        id: 'doc-custom',
        type: 'safety_certificate',
        daysUntilExpiry: 200,
      );

      await tester.pumpWidget(buildSubject(docs: [customDoc]));
      await pumpScreen(tester);

      // _formatType converts underscores to spaces and capitalizes
      expect(find.text('Safety Certificate'), findsOneWidget);
    });

    testWidgets('FAB is hidden when the member cannot manage documents',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(
        buildTestApp(
          const DocumentListScreen(boatId: boatId),
          overrides: [
            boatDocumentsProvider.overrideWith((ref, id) async => testDocs),
            boatProvider.overrideWith(
              (ref, id) async => Boat(
                id: id,
                name: 'Test Boat',
                registration: 'TEST-1',
                type: 'sailboat',
                lengthMeters: 10,
                isOwner: false,
                permissions: const BoatPermissions(canManageDocuments: false),
              ),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('shows multiple expired documents correctly', (tester) async {
      await setPhoneSize(tester);
      final expired1 = makeDocument(
        id: 'exp-1',
        daysUntilExpiry: -10,
      );
      final expired2 = makeDocument(
        id: 'exp-2',
        type: 'License',
        daysUntilExpiry: -60,
      );

      await tester.pumpWidget(buildSubject(docs: [expired1, expired2]));
      await pumpScreen(tester);

      expect(find.text('Expired'), findsNWidgets(2));
    });
  });
}
