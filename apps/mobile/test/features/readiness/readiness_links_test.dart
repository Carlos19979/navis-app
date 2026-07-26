import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/readiness/presentation/readiness_links.dart';

void main() {
  group('readinessRoute', () {
    test('maintenance entries point at the maintenance screen', () {
      expect(
        readinessRoute(
          boatId: 'b1',
          category: 'maintenance',
          ref: 'engine_service',
        ),
        '/boats/b1/maintenance',
      );
      expect(
        readinessRoute(boatId: 'b1', category: 'maintenance'),
        '/boats/b1/maintenance',
      );
    });

    test('the engine_service ref wins over an odd category', () {
      expect(
        readinessRoute(
          boatId: 'b1',
          category: 'documents',
          ref: 'engine_service',
        ),
        '/boats/b1/maintenance',
      );
    });

    test('documents and safety gear point at the documents screen', () {
      expect(
        readinessRoute(boatId: 'b1', category: 'documents', ref: 'itb'),
        '/boats/b1/documents',
      );
      expect(
        readinessRoute(boatId: 'b1', category: 'safety_gear', ref: 'flares'),
        '/boats/b1/documents',
      );
    });

    test('an unknown category has no destination', () {
      expect(readinessRoute(boatId: 'b1', category: 'crew'), isNull);
      expect(readinessRoute(boatId: 'b1', category: ''), isNull);
    });

    test('an empty boat id has no destination', () {
      expect(readinessRoute(boatId: '', category: 'documents'), isNull);
    });
  });
}
