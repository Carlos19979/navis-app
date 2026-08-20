@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';
import 'package:navis_mobile/features/profile/presentation/screens/profile_screen.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

/// Cuenta — Profile with Settings folded into it.
///
/// Baseline worth having because this is the screen the merge created: it used
/// to be two levels for the same thing, with Profile a root tab that had a back
/// button on it. It is also the longest page after Today, so the full-height
/// shot is the one that shows the merge worked.
/// Answers the notification preferences locally: without it the shot shows the
/// section's error state, which says nothing about the design.
class _PrefsRepository implements NotificationFeedRepository {
  @override
  Future<List<NotificationPreference>> getPreferences() async => [
        for (final c in NotificationCategory.values)
          NotificationPreference(category: c, enabled: c.wire != 'event-live'),
      ];

  @override
  Future<List<NotificationPreference>> setPreferences(
    List<NotificationPreference> preferences,
  ) async =>
      preferences;

  @override
  Future<PaginatedResponse<AppNotification>> getNotifications({
    String? cursor,
    int limit = 20,
  }) async =>
      const PaginatedResponse<AppNotification>(items: []);

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}

void main() {
  setUpAll(loadTestFonts);

  final profile = UserProfile(
    id: 'user-1',
    email: 'carlos@navis.app',
    displayName: 'Carlos',
    createdAt: DateTime(2026, 1, 15),
  );

  for (final brightness in Brightness.values) {
    testWidgets('account — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const ProfileScreen(),
        brightness: brightness,
        settle: false,
        overrides: [
          await prefsOverride(),
          profileProvider.overrideWithValue(profile),
          notificationFeedRepositoryProvider
              .overrideWithValue(_PrefsRepository()),
          ...planOverrides(),
        ],
      );
      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile(goldenPath('account', brightness)),
      );
    });
  }

  testWidgets('account, whole page', (tester) async {
    await pumpGolden(
      tester,
      const ProfileScreen(),
      brightness: Brightness.light,
      size: const Size(390, 1800),
      settle: false,
      overrides: [
        await prefsOverride(),
        profileProvider.overrideWithValue(profile),
        ...planOverrides(),
      ],
    );
    await expectLater(
      find.byType(ProfileScreen),
      matchesGoldenFile('goldens/account_full.png'),
    );
  });
}
