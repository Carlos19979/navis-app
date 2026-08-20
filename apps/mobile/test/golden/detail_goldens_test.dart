@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/presentation/screens/document_detail_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/event_detail_screen.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/screens/bookings_screen.dart';

import 'package:navis_mobile/shared/models/paginated_response.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

class _MockSharedRepository extends Mock implements SharedRepository {}

class _FakeFeedRepository implements NotificationFeedRepository {
  @override
  Future<PaginatedResponse<AppNotification>> getNotifications({
    String? cursor,
    int limit = 20,
  }) async =>
      PaginatedResponse<AppNotification>(
        items: [
          AppNotification(
            id: 'n1',
            category: NotificationCategory.reminders,
            title: 'El seguro caduca en 30 días',
            body: 'Luna Azul · Seguro RC',
            createdAt: DateTime(2026, 8, 18, 8),
          ),
          AppNotification(
            id: 'n2',
            category: NotificationCategory.boatActivity,
            title: 'Maria ha registrado un gasto',
            body: 'Amarre · 1.450 €',
            createdAt: DateTime(2026, 8, 16, 19, 20),
            readAt: DateTime(2026, 8, 17),
          ),
          AppNotification(
            id: 'n3',
            category: NotificationCategory.regattaUpdates,
            title: 'Copa del Rey: te esperan el 31 de julio',
            createdAt: DateTime(2026, 8, 12, 9),
            readAt: DateTime(2026, 8, 12, 10),
          ),
        ],
      );

  @override
  Future<int> getUnreadCount() async => 1;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<List<NotificationPreference>> getPreferences() async => const [];

  @override
  Future<List<NotificationPreference>> setPreferences(
    List<NotificationPreference> preferences,
  ) async =>
      preferences;
}

/// Baselines for the detail screens the redesign reworked but that had none.
///
/// Every one of them lost a decorated frame this phase — a gradient severity
/// stripe, a tinted icon disc, a card per row — so they are exactly the shots
/// worth being able to compare against next time.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    // The bookings screen reads the signed-in user to mark «You» on a slot.
    await signInFakeUser();
  });

  Future<void> shot(
    WidgetTester tester,
    Widget screen,
    String name,
    Brightness brightness, {
    required List<Override> overrides,
    Type? finderType,
  }) async {
    await pumpGolden(
      tester,
      screen,
      brightness: brightness,
      settle: false,
      overrides: overrides,
    );
    await expectLater(
      find.byType(finderType ?? screen.runtimeType),
      matchesGoldenFile(goldenPath(name, brightness)),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('document detail — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const DocumentDetailScreen(documentId: 'doc-1'),
        'document_detail',
        brightness,
        overrides: [
          documentProvider.overrideWith(
            (ref, id) async => makeDocument(
              type: 'insurance_rc',
              daysUntilExpiry: 40,
            ).copyWith(
              lastRenewalDate: DateTime(2026, 3, 2),
              lastRenewalCost: 420.5,
              lastRenewalProvider: 'Marina Insurance SL',
              notes: 'Póliza a todo riesgo con franquicia de 300 €.',
            ),
          ),
        ],
      );
    });

    testWidgets('bookings — ${brightness.name}', (tester) async {
      final now = DateTime.now();
      await shot(
        tester,
        const BookingsScreen(boatId: 'boat-1'),
        'bookings',
        brightness,
        overrides: [
          sharedRepositoryProvider.overrideWithValue(_MockSharedRepository()),
          boatBookingsProvider.overrideWith(
            (ref, id) async => [
              makeBooking(
                startsAt: DateTime(now.year, now.month, now.day, 10),
                endsAt: DateTime(now.year, now.month, now.day, 18),
              ),
            ],
          ),
          boatMembersProvider.overrideWith((ref, id) async => const []),
        ],
      );
    });

    testWidgets('event detail — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const EventDetailScreen(eventId: 'event-1'),
        'event_detail',
        brightness,
        overrides: [
          eventProvider.overrideWith((ref, id) async => makeEvent()),
        ],
      );
    });

    testWidgets('notifications — ${brightness.name}', (tester) async {
      await shot(
        tester,
        const NotificationsScreen(),
        'notifications',
        brightness,
        overrides: [
          notificationFeedRepositoryProvider
              .overrideWithValue(_FakeFeedRepository()),
        ],
      );
    });
  }
}
