import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/moderation/presentation/widgets/moderation_menu.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

Widget _host(Widget action) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(appBar: AppBar(actions: [action])),
      ),
    );

void main() {
  testWidgets('offers Report and Block when content has an owner',
      (tester) async {
    await tester.pumpWidget(_host(const ModerationMenuButton(
      contentType: 'group',
      contentId: 'g1',
      ownerUserId: 'u2',
    )));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block user'), findsOneWidget);
  });

  testWidgets('offers only Report when there is no owner id (events)',
      (tester) async {
    await tester.pumpWidget(_host(const ModerationMenuButton(
      contentType: 'event',
      contentId: 'e1',
    )));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Block user'), findsNothing);
  });

  testWidgets('report opens the reason picker', (tester) async {
    await tester.pumpWidget(_host(const ModerationMenuButton(
      contentType: 'group',
      contentId: 'g1',
      ownerUserId: 'u2',
    )));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(find.text('Why are you reporting this?'), findsOneWidget);
    expect(find.text('Harassment'), findsOneWidget);
  });
}
