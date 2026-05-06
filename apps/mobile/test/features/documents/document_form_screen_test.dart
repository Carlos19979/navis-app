import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_form_screen.dart';

import '../../helpers/test_helpers.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

class FakeDocument extends Fake implements Document {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
    registerFallbackValue(FakeDocument());
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
      // Default selected type is Registration
      expect(find.text('Registration'), findsOneWidget);
    });

    testWidgets('dropdown shows all document types when opened',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap the dropdown to open it
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Verify key document types near the top are visible
      expect(find.text('Insurance'), findsAtLeastNWidgets(1));
      expect(find.text('Inspection'), findsAtLeastNWidgets(1));
      expect(find.text('License'), findsAtLeastNWidgets(1));
      expect(find.text('Safety Certificate'), findsAtLeastNWidgets(1));
    });

    testWidgets('can select a different document type from dropdown',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Select Insurance
      await tester.tap(find.text('Insurance').last);
      await tester.pumpAndSettle();

      // Dropdown should now show Insurance as selected
      expect(find.text('Insurance'), findsOneWidget);
    });

    testWidgets('shows expiry date field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Expiry Date'), findsOneWidget);
    });

    testWidgets('shows alert days before expiry field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Alert Days Before Expiry'), findsOneWidget);
      // Default value is 30
      expect(find.text('30'), findsOneWidget);
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

    testWidgets('alert days validates non-numeric input', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the alert days field by its label text
      final alertField = find.widgetWithText(
        TextFormField,
        'Alert Days Before Expiry',
      );
      expect(alertField, findsOneWidget);

      // Clear and type invalid value
      await tester.enterText(alertField, 'abc');
      await tester.pumpAndSettle();

      // Scroll down to Save button
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Tap save to trigger validation
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid number'), findsOneWidget);
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

    testWidgets('document type dropdown is disabled in renew mode',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        documentId: 'doc-1',
        isRenew: true,
        existingDocument: existingDoc,
      ));
      await tester.pumpAndSettle();

      // The dropdown should be present but disabled (onChanged is null)
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
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
}
