import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_viewer.dart';

import '../helpers/helpers.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  late _MockStorageService storage;

  setUp(() {
    storage = _MockStorageService();
    // Signed resolution "offline": thumbnails fall back to the placeholder
    // so no network image is fetched in tests.
    when(() => storage.signedDocumentUrl(any())).thenAnswer((_) async => null);
  });

  Widget subject({
    List<String> urls = const [],
    ValueChanged<List<String>>? onChanged,
    Future<String> Function(File file)? upload,
    int maxPhotos = 10,
    Future<bool> Function()? onLimitReached,
  }) {
    return buildTestAppWithScaffold(
      NavisPhotoStrip(
        label: 'Photos',
        urls: urls,
        signed: true,
        onChanged: onChanged ?? (_) {},
        upload: upload ?? (file) async => 'https://x.test/uploaded.jpg',
        maxPhotos: maxPhotos,
        onLimitReached: onLimitReached,
        pickOverride: (_) async => File('fake-photo.jpg'),
      ),
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
  }

  group('NavisPhotoStrip', () {
    testWidgets('renders label, thumbnails and the add tile', (tester) async {
      await tester.pumpWidget(subject(
        urls: const ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
      ));
      await pumpScreen(tester);

      expect(find.text('Photos'), findsOneWidget);
      expect(find.byType(NavisPhotoThumb), findsNWidgets(2));
      expect(find.byTooltip('Add Photo'), findsOneWidget);
    });

    testWidgets('add tile picks a photo, uploads it and appends the url',
        (tester) async {
      File? uploaded;
      List<String>? changed;
      await tester.pumpWidget(subject(
        urls: const ['https://x.test/a.jpg'],
        upload: (file) async {
          uploaded = file;
          return 'https://x.test/uploaded.jpg';
        },
        onChanged: (u) => changed = u,
      ));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Add Photo'));
      await pumpScreen(tester);
      await tester.tap(find.text('Take Photo'));
      await pumpScreen(tester);

      expect(uploaded?.path, 'fake-photo.jpg');
      expect(changed, ['https://x.test/a.jpg', 'https://x.test/uploaded.jpg']);
    });

    testWidgets('at the cap the add tile calls onLimitReached instead',
        (tester) async {
      var limitHit = false;
      await tester.pumpWidget(subject(
        urls: const ['https://x.test/a.jpg'],
        maxPhotos: 1,
        onLimitReached: () async {
          limitHit = true;
          return false;
        },
      ));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Add Photo'));
      await pumpScreen(tester);

      expect(limitHit, isTrue);
      // Declined (no upgrade): the source picker never opens.
      expect(find.text('Take Photo'), findsNothing);
    });

    testWidgets('remove button drops the photo', (tester) async {
      List<String>? changed;
      await tester.pumpWidget(subject(
        urls: const ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
        onChanged: (u) => changed = u,
      ));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Remove').first);
      await pumpScreen(tester);

      expect(changed, ['https://x.test/b.jpg']);
    });

    testWidgets('tapping a thumbnail opens the fullscreen viewer',
        (tester) async {
      await tester.pumpWidget(subject(
        urls: const ['https://x.test/a.jpg', 'https://x.test/b.jpg'],
      ));
      await pumpScreen(tester);

      await tester.tap(find.byType(NavisPhotoThumb).first);
      await pumpScreen(tester);

      expect(find.byType(NavisPhotoViewer), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });

  group('NavisPhotoThumbRow', () {
    testWidgets('shows up to four thumbs and a +N overflow chip',
        (tester) async {
      final urls = [
        for (var i = 0; i < 6; i++) 'https://x.test/$i.jpg',
      ];
      await tester.pumpWidget(buildTestAppWithScaffold(
        NavisPhotoThumbRow(urls: urls, signed: true),
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      ));
      await pumpScreen(tester);

      expect(find.byType(NavisPhotoThumb), findsNWidgets(4));
      expect(find.text('+2'), findsOneWidget);
    });
  });
}
