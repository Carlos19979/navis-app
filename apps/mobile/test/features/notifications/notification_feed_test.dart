import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_link.dart';
import 'package:navis_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:navis_mobile/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class MockFeedRepository extends Mock implements NotificationFeedRepository {}

AppNotification notification({
  String id = 'n1',
  NotificationCategory? category = NotificationCategory.reminders,
  String title = 'Documento a punto de caducar',
  String body = '',
  String? linkType,
  String? linkId,
  DateTime? readAt,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    category: category,
    title: title,
    body: body,
    linkType: linkType,
    linkId: linkId,
    readAt: readAt,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 2)),
  );
}

void main() {
  late MockFeedRepository repo;

  setUp(() {
    repo = MockFeedRepository();
    when(() => repo.getUnreadCount()).thenAnswer((_) async => 0);
    when(() => repo.markRead(any())).thenAnswer((_) async {});
    when(() => repo.markAllRead()).thenAnswer((_) async {});
    when(() => repo.getNotifications(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => const PaginatedResponse<AppNotification>(items: []));
  });

  Widget wrap(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        notificationFeedRepositoryProvider.overrideWithValue(repo),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(path: '/home', builder: (_, __) => child),
            GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationsScreen(),
            ),
            GoRoute(
              path: '/documents/:id',
              builder: (_, state) => Scaffold(
                body: Text('Documento ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
      ),
    );
  }

  Widget bellHost() => const Scaffold(
        body: Row(children: [NotificationBell()]),
      );

  group('NotificationBell', () {
    testWidgets('shows no badge when everything is read', (tester) async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 0);

      await tester.pumpWidget(wrap(bellHost()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the unread count', (tester) async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 3);

      await tester.pumpWidget(wrap(bellHost()));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps the badge at 9+ so a big count still fits',
        (tester) async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 42);

      await tester.pumpWidget(wrap(bellHost()));
      await tester.pumpAndSettle();

      expect(find.text('9+'), findsOneWidget);
    });

    // A failing count must not take the app bar down with it.
    testWidgets('degrades to no badge when the count cannot be read',
        (tester) async {
      when(() => repo.getUnreadCount()).thenThrow(Exception('offline'));

      await tester.pumpWidget(wrap(bellHost()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the notification history', (tester) async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [notification(title: 'Reserva creada')],
              ));

      await tester.pumpWidget(wrap(bellHost()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Reserva creada'), findsOneWidget);
    });
  });

  group('NotificationsScreen', () {
    testWidgets('lists notifications and marks the unread ones',
        (tester) async {
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [
                  notification(title: 'Sin leer'),
                  notification(
                    id: 'n2',
                    title: 'Ya leida',
                    readAt: DateTime.now(),
                  ),
                ],
              ));

      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sin leer'), findsOneWidget);
      expect(find.text('Ya leida'), findsOneWidget);
      // «Mark all as read» only shows while something is unread — an icon
      // with that tooltip now, because the label ran off the bar.
      expect(find.byTooltip('Mark all as read'), findsOneWidget);
    });

    testWidgets('empty state explains what will show up here', (tester) async {
      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
      expect(find.byTooltip('Mark all as read'), findsNothing);
    });

    testWidgets('tapping a notification marks it read and follows its link',
        (tester) async {
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [
                  notification(
                    title: 'Seguro caduca',
                    linkType: 'document',
                    linkId: 'doc-9',
                  ),
                ],
              ));

      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seguro caduca'));
      await tester.pumpAndSettle();

      verify(() => repo.markRead('n1')).called(1);
      expect(find.text('Documento doc-9'), findsOneWidget);
    });

    testWidgets('a notification with no link is still marked read',
        (tester) async {
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [notification(title: 'Sin destino')],
              ));

      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sin destino'));
      await tester.pumpAndSettle();

      verify(() => repo.markRead('n1')).called(1);
      expect(find.text('Sin destino'), findsOneWidget);
    });

    testWidgets('mark all read clears every unread marker', (tester) async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 2);
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [
                  notification(title: 'Una'),
                  notification(id: 'n2', title: 'Otra'),
                ],
              ));

      await tester.pumpWidget(wrap(const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();

      verify(() => repo.markAllRead()).called(1);
      // The action disappears once nothing is unread.
      expect(find.byTooltip('Mark all as read'), findsNothing);
    });
  });

  group('feed notifier', () {
    test('marking read decrements the badge and reverts on failure', () async {
      when(() => repo.getUnreadCount()).thenAnswer((_) async => 2);
      when(() => repo.getNotifications(cursor: any(named: 'cursor')))
          .thenAnswer((_) async => PaginatedResponse<AppNotification>(
                items: [notification()],
              ));
      when(() => repo.markRead('n1')).thenThrow(Exception('offline'));

      final container = ProviderContainer(overrides: [
        notificationFeedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(notificationFeedProvider.future);
      await container.read(unreadNotificationCountProvider.future);

      await expectLater(
        container.read(notificationFeedProvider.notifier).markRead('n1'),
        throwsException,
      );

      // The optimistic update was rolled back: still unread, badge re-read.
      final items = container.read(notificationFeedProvider).valueOrNull!;
      expect(items.single.isRead, isFalse);
      expect(container.read(unreadNotificationCountProvider).valueOrNull, 2);
    });

    test('loadMore appends the next page only once', () async {
      when(() => repo.getNotifications()).thenAnswer(
        (_) async => PaginatedResponse<AppNotification>(
          items: [notification()],
          nextCursor: 'cursor-2',
        ),
      );
      when(() => repo.getNotifications(cursor: 'cursor-2')).thenAnswer(
        (_) async => PaginatedResponse<AppNotification>(
          items: [notification(id: 'n2')],
        ),
      );

      final container = ProviderContainer(overrides: [
        notificationFeedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(notificationFeedProvider.future);
      final notifier = container.read(notificationFeedProvider.notifier);

      // The scroll listener fires repeatedly near the end of the list; the
      // guard is what stops the same cursor being paged twice.
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      await notifier.loadMore();

      expect(container.read(notificationFeedProvider).valueOrNull!.length, 2);
      verify(() => repo.getNotifications(cursor: 'cursor-2')).called(1);
    });

    test('preferences toggle sends the whole set and reverts on failure',
        () async {
      final all = [
        for (final category in NotificationCategory.values)
          NotificationPreference(category: category, enabled: true),
      ];
      when(() => repo.getPreferences()).thenAnswer((_) async => all);
      when(() => repo.setPreferences(any())).thenThrow(Exception('offline'));

      final container = ProviderContainer(overrides: [
        notificationFeedRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(notificationPreferencesProvider.future);

      await expectLater(
        container
            .read(notificationPreferencesProvider.notifier)
            .toggle(NotificationCategory.reminders, false),
        throwsException,
      );

      final prefs =
          container.read(notificationPreferencesProvider).valueOrNull!;
      expect(
        prefs
            .firstWhere((p) => p.category == NotificationCategory.reminders)
            .enabled,
        isTrue,
      );
    });
  });

  group('notificationPath', () {
    test('maps every routable type', () {
      expect(notificationPath('document', 'd1'), '/documents/d1');
      expect(notificationPath('regatta', 'r1'), '/regattas/r1');
      expect(notificationPath('group', 'g1'), '/groups/g1');
      expect(notificationPath('event', 'e1'), '/events/e1');
      expect(notificationPath('trip', 't1'), '/trips/t1');
      expect(notificationPath('boat', 'b1'), '/boats/b1');
    });

    test('returns null for nothing to open', () {
      expect(notificationPath(null, 'x'), isNull);
      expect(notificationPath('document', null), isNull);
      expect(notificationPath('document', ''), isNull);
      // A type a newer server may send and this build cannot route.
      expect(notificationPath('invoice', 'i1'), isNull);
    });
  });

  group('category parsing', () {
    test('accepts the API wire values', () {
      expect(NotificationCategory.tryParse('reminders'),
          NotificationCategory.reminders);
      expect(NotificationCategory.tryParse('boat-activity'),
          NotificationCategory.boatActivity);
    });

    test('an unknown category does not break the feed', () {
      expect(NotificationCategory.tryParse('gossip'), isNull);
      expect(NotificationCategory.tryParse(null), isNull);
    });
  });
}
