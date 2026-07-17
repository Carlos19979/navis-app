import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/documents/data/models/document_model.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_form_screen.dart';

import '../../helpers/helpers.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

class FakeDocument extends Fake implements Document {}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    registerFallbackValue(FakeDocument());
    await signInFakeUser();
  });

  const boatId = 'boat-1';

  late MockDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockDocumentRepository();
  });

  Widget buildSubject({
    String? documentId,
    bool isRenew = false,
    Document? existingDocument,
  }) {
    final overrides = <Override>[
      documentRepositoryProvider.overrideWithValue(mockRepository),
      boatDocumentsProvider.overrideWith(
        (ref, id) async => <Document>[],
      ),
    ];

    // If editing, provide the document via documentProvider
    if (documentId != null && existingDocument != null) {
      overrides.add(
        documentProvider.overrideWith(
          (ref, id) async => existingDocument,
        ),
      );
    }

    return buildTestApp(
      DocumentFormScreen(
        boatId: boatId,
        documentId: documentId,
        isRenew: isRenew,
      ),
      overrides: overrides,
    );
  }

  /// Routed variant for flows that reach `context.pop()` after saving.
  Widget buildRoutedSubject() {
    return buildRoutedTestApp(
      const DocumentFormScreen(boatId: boatId),
      overrides: [
        documentRepositoryProvider.overrideWithValue(mockRepository),
        boatDocumentsProvider.overrideWith(
          (ref, id) async => <Document>[],
        ),
      ],
    );
  }

  /// The [FilterChip] rendering [label] (e.g. '30 days').
  FilterChip chipFor(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilterChip),
        ),
      );

  group('DocumentFormScreen - Create Mode', () {
    testWidgets('shows New Document title in create mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('New Document'), findsOneWidget);
    });

    testWidgets('shows Document Type section header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Document Type'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Notes section header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows document type dropdown', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.byType(DropdownButtonFormField<String>),
        findsOneWidget,
      );
      // Default selected type is the first canonical type (itb).
      expect(find.text('Technical Inspection (ITB)'), findsOneWidget);
    });

    testWidgets('dropdown shows all document types when opened',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Verify key canonical document types near the top are visible
      expect(find.text('Third-Party Insurance'), findsAtLeastNWidgets(1));
      expect(find.text('Full Insurance'), findsAtLeastNWidgets(1));
      expect(find.text('Life Raft'), findsAtLeastNWidgets(1));
      expect(find.text('Navigation License'), findsAtLeastNWidgets(1));
    });

    testWidgets('can select a different document type from dropdown',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Select Third-Party Insurance (canonical insurance_rc)
      await tester.tap(find.text('Third-Party Insurance').last);
      await tester.pumpAndSettle();

      // Dropdown should now show it as selected
      expect(find.text('Third-Party Insurance'), findsOneWidget);
    });

    testWidgets('shows expiry date field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Expiry Date'), findsOneWidget);
    });

    testWidgets('shows alert day chips with 30 and 7 preselected',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Alert Days Before Expiry'), findsOneWidget);
      // Preset thresholds render as chips (plus the custom-entry chip).
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('15 days'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      // Default selection mirrors the API default [30, 7].
      expect(chipFor(tester, '30 days').selected, isTrue);
      expect(chipFor(tester, '7 days').selected, isTrue);
      expect(chipFor(tester, '15 days').selected, isFalse);
      expect(chipFor(tester, '1 day').selected, isFalse);
    });

    testWidgets('shows notes field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Notes (optional)'), findsOneWidget);
    });

    testWidgets('shows Save Document button in create mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows add scan area', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Add Scan'), findsOneWidget);
    });

    testWidgets('deselecting every alert chip blocks saving', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Clear the default [30, 7] selection.
      await tester.tap(find.text('30 days'));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Select at least one alert'), findsOneWidget);
      verifyNever(() => mockRepository.createDocument(any()));
    });

    testWidgets('custom chip adds a new threshold via dialog', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '45');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(chipFor(tester, '45 days').selected, isTrue);
    });

    testWidgets('custom chip rejects non-numeric input with a snackbar',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expectSnackbar(tester, 'Please enter a valid number');
    });

    testWidgets('saving sends the selected alert days as an array',
        (tester) async {
      when(() => mockRepository.createDocument(any()))
          .thenAnswer((_) async => makeDocument());

      setPhoneSize(tester);
      await tester.pumpWidget(buildRoutedSubject());
      await tester.pumpAndSettle();

      // Start from [30, 7]: select 15, deselect 7 → [30, 15].
      await tester.tap(find.text('15 days'));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockRepository.createDocument(captureAny()),
      ).captured.single as Document;
      expect(captured.alertDays, [30, 15]);
      expect(captured.alertDaysBefore, 30);

      // The wire format carries the full array.
      final json = DocumentModel.fromEntity(captured).toJson();
      expect(json['alert_days'], [30, 15]);
    });

    testWidgets('can enter notes text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final notesField = find.widgetWithText(
        TextFormField,
        'Notes (optional)',
      );

      await tester.enterText(notesField, 'Annual renewal');
      await tester.pumpAndSettle();

      expect(find.text('Annual renewal'), findsOneWidget);
    });

    testWidgets('expiry date field opens date picker on tap', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find and tap the expiry date field area
      final expiryField = find.text('Expiry Date');
      expect(expiryField, findsOneWidget);

      // Tap the GestureDetector wrapping the date field
      await tester.tap(expiryField);
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('date picker can be dismissed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Expiry Date'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss by tapping Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('date picker OK confirms selection', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Expiry Date'));
      await tester.pumpAndSettle();

      // Confirm the selected date
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('does not show renewal section in create mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Last Renewal'), findsNothing);
      expect(find.text('Renewal Cost'), findsNothing);
      expect(find.text('Provider / Company'), findsNothing);
    });
  });

  group('DocumentFormScreen - Edit Mode', () {
    final existingDoc = makeDocument();

    testWidgets('shows Edit Document title in edit mode', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Edit Document'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Edit Document button in edit mode', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Edit Document'), findsAtLeastNWidgets(1));
    });

    testWidgets('pre-populates notes from existing document', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      // The makeDocument factory sets notes to 'Test document'
      expect(find.text('Test document'), findsOneWidget);
    });

    testWidgets('pre-populates selected type from existing document',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Insurance'), findsOneWidget);
    });
  });

  group('DocumentFormScreen - Renew Mode', () {
    final existingDoc = makeDocument(
      daysUntilExpiry: -10, // Expired
    );

    testWidgets('shows Renew Document title', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      // Title in AppBar + button label both say 'Renew Document'
      expect(find.text('Renew Document'), findsNWidgets(2));
    });

    testWidgets('shows Renew Document button', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Renew Document'), findsNWidgets(2)); // title + button
    });

    testWidgets('shows renewal details section', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Last Renewal'), findsOneWidget);
      expect(find.text('Renewal Cost'), findsOneWidget);
      expect(find.text('Provider / Company'), findsOneWidget);
    });

    testWidgets('document type dropdown is editable in renew mode',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      // Renew shares the same editable fields as edit (onChanged is set).
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNotNull);
    });

    testWidgets('can enter renewal cost', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      final costField = find.widgetWithText(
        TextFormField,
        'Renewal Cost',
      );
      expect(costField, findsOneWidget);

      await tester.enterText(costField, '150.00');
      await tester.pumpAndSettle();

      expect(find.text('150.00'), findsOneWidget);
    });

    testWidgets('can enter provider name', (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      final providerField = find.widgetWithText(
        TextFormField,
        'Provider / Company',
      );
      expect(providerField, findsOneWidget);

      await tester.enterText(providerField, 'Mapfre');
      await tester.pumpAndSettle();

      expect(find.text('Mapfre'), findsOneWidget);
    });
  });

  group('DocumentFormScreen - Form Interactions', () {
    testWidgets('scan area is tappable and shows bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Scroll down to the scan area
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Tap the scan area
      await tester.tap(find.text('Add Scan'));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with camera and gallery options
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets('scan bottom sheet can be dismissed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Scan'));
      await tester.pumpAndSettle();

      // Dismiss by tapping outside
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.text('Take Photo'), findsNothing);
    });

    testWidgets('all form sections are visible on scroll', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Document Type section
      expect(find.text('Document Type'), findsAtLeastNWidgets(1));

      // Scroll down to see the rest
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Notes section and Save button should be visible
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('form has back navigation via app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // NavisAppBar with showBack: true renders a back button
      expect(
        find.byIcon(Icons.arrow_back_ios_new_rounded),
        findsOneWidget,
      );
    });

    testWidgets('handles document with custom type not in default list',
        (tester) async {
      final customDoc = makeDocument(
        id: 'doc-custom',
        type: 'Diving Certificate',
        daysUntilExpiry: 100,
      );

      await tester.pumpWidget(buildSubject(
        documentId: 'doc-custom',
        existingDocument: customDoc,
      ));
      await tester.pumpAndSettle();

      // The custom type should be dynamically added and shown
      expect(find.text('Diving Certificate'), findsOneWidget);
    });
  });

  group('DocumentFormScreen - Custom Type', () {
    Future<void> selectCustomType(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other (custom)').last);
      await tester.pumpAndSettle();
    }

    testWidgets('dropdown offers Other (custom)', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Other (custom)'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecting custom reveals the required name field',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Custom document name'), findsNothing);

      await selectCustomType(tester);

      expect(find.text('Custom document name'), findsOneWidget);
    });

    testWidgets('saving custom without a name shows a validation error',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await selectCustomType(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a document name'), findsOneWidget);
      verifyNever(() => mockRepository.createDocument(any()));
    });

    testWidgets('saving custom sends custom_name', (tester) async {
      when(() => mockRepository.createDocument(any()))
          .thenAnswer((_) async => makeDocument());

      setPhoneSize(tester);
      await tester.pumpWidget(buildRoutedSubject());
      await tester.pumpAndSettle();

      await selectCustomType(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Custom document name'),
        'Diving Permit',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockRepository.createDocument(captureAny()),
      ).captured.single as Document;
      expect(captured.type, 'custom');
      expect(captured.customName, 'Diving Permit');

      final json = DocumentModel.fromEntity(captured).toJson();
      expect(json['type'], 'custom');
      expect(json['custom_name'], 'Diving Permit');
    });

    testWidgets('non-custom types do not send custom_name', (tester) async {
      await signInFakeUser();
      when(() => mockRepository.createDocument(any()))
          .thenAnswer((_) async => makeDocument());

      setPhoneSize(tester);
      await tester.pumpWidget(buildRoutedSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockRepository.createDocument(captureAny()),
      ).captured.single as Document;
      expect(captured.customName, isNull);
      expect(
        DocumentModel.fromEntity(captured).toJson(),
        isNot(contains('custom_name')),
      );
    });

    testWidgets('edit mode pre-fills custom name and alert chips',
        (tester) async {
      final customDoc = makeDocument(
        id: 'doc-9',
        type: 'custom',
        customName: 'Marina Permit',
        alertDays: [15, 1],
      );

      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-9',
        existingDocument: customDoc,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Marina Permit'), findsOneWidget);
      expect(chipFor(tester, '15 days').selected, isTrue);
      expect(chipFor(tester, '1 day').selected, isTrue);
      expect(chipFor(tester, '30 days').selected, isFalse);
      expect(chipFor(tester, '7 days').selected, isFalse);
    });
  });
}
