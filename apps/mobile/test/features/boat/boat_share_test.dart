// Sharing a boat has to hand the invite to whatever app the owner actually
// uses to talk to their crew — WhatsApp, Telegram, Mail. It used to only drop
// the code on the clipboard, which left the user with nothing to tap and no
// idea where the code went. These tests pin the user-visible outcome: the OS
// share sheet is summoned with a message the recipient can act on, and copying
// survives as the secondary option.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/boat_join_link.dart';

import '../../helpers/helpers.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';

class _MockShareRepository extends Mock implements BoatShareRepository {}

/// The channel share_plus uses to summon the native sheet
/// (`MethodChannelShare.channel` in share_plus_platform_interface). In a
/// widget test no plugin registers itself, so `SharePlatform.instance` stays
/// the method-channel implementation and every `Share.share` lands here.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  const boatId = 'boat-1';
  const shareCode = 'ZX9Q4T';

  late _MockShareRepository repo;
  late List<MethodCall> shareSheetCalls;
  late List<MethodCall> clipboardWrites;

  setUp(() {
    repo = _MockShareRepository();
    when(() => repo.shareCode(boatId)).thenAnswer((_) async => shareCode);
    when(() => repo.listMembers(boatId))
        .thenAnswer((_) async => const <BoatMember>[]);
    shareSheetCalls = <MethodCall>[];
    clipboardWrites = <MethodCall>[];
  });

  /// Stands in for the OS share sheet. [fails] makes the platform side blow up
  /// the way it does when there is no app able to receive the intent.
  void interceptShareSheet(WidgetTester tester, {bool fails = false}) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shareSheetCalls.add(call);
      if (fails) {
        throw PlatformException(
          code: 'error',
          message: 'No Activity found to handle Intent',
        );
      }
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_shareChannel, null));
  }

  /// Records clipboard writes without disturbing anything else on the
  /// platform channel.
  void interceptClipboard(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboardWrites.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Future<Widget> subject() async => buildRoutedTestApp(
        const TodayScreen(),
        // makeBoat defaults to id 'boat-1' / name 'Luna Azul'.
        overrides: [
          ...await todayOverrides(),
          boatShareRepositoryProvider.overrideWithValue(repo),
        ],
      );

  /// Walks the owner's real path: scroll to the "Share boat" action, tap it,
  /// wait for the code round-trip and the sheet animation.
  Future<void> openShareSheet(WidgetTester tester) async {
    // Keyed, not `byType(Scrollable).first`: Today nests scrollables (the photo
    // strip, the boat picker) and which one comes first depends on the fixture.
    await scrollUntilVisible(tester, find.text('Share boat'), todayScrollKey);
    await tester.tap(find.text('Share boat'));
    await pumpFrames(tester, frames: 8);
  }

  /// The text handed to the OS on the most recent share.
  String sharedText() =>
      (shareSheetCalls.last.arguments as Map<Object?, Object?>)['text']
          as String;

  testWidgets('sharing summons the native share sheet, not just the clipboard',
      (tester) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    interceptShareSheet(tester);
    interceptClipboard(tester);

    await tester.pumpWidget(await subject());
    await pumpFrames(tester, frames: 8);
    await openShareSheet(tester);

    expect(find.text(shareCode), findsOneWidget,
        reason: 'the sheet shows the invite code it is about to share');

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await pumpFrames(tester, frames: 8);

    expect(
      shareSheetCalls,
      hasLength(1),
      reason: 'Share must reach the OS sheet so WhatsApp/Telegram/Mail '
          'are offered; copying to the clipboard alone is the old bug',
    );
    expect(shareSheetCalls.single.method, 'share');
    expect(sharedText(), contains(shareCode));
    expect(clipboardWrites, isEmpty,
        reason: 'Share is not a silent copy-to-clipboard');

    await drain(tester);
  });

  testWidgets('the shared message carries the boat name and the join link',
      (tester) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    interceptShareSheet(tester);

    await tester.pumpWidget(await subject());
    await pumpFrames(tester, frames: 8);
    await openShareSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await pumpFrames(tester, frames: 8);

    final text = sharedText();
    // The recipient needs to know which boat, and needs something tappable.
    expect(text, contains('Luna Azul'));
    expect(text, contains(shareCode));
    // An https link, not the `navis://` scheme it used to be: WhatsApp does not
    // linkify a custom scheme, and on a phone without Navis tapping it did
    // nothing. The API page bounces into the app or offers the download.
    expect(text, contains(boatJoinLink(shareCode)));
    expect(text, contains('/join?code=$shareCode'));

    await drain(tester);
  });

  testWidgets('copying the code still works as the secondary option',
      (tester) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    interceptShareSheet(tester);
    interceptClipboard(tester);

    await tester.pumpWidget(await subject());
    await pumpFrames(tester, frames: 8);
    await openShareSheet(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await pumpFrames(tester, frames: 8);

    expect(clipboardWrites, hasLength(1));
    expect(
      (clipboardWrites.single.arguments as Map<Object?, Object?>)['text'],
      shareCode,
    );
    expectSnackbar(tester, 'Code copied');
    expect(shareSheetCalls, isEmpty,
        reason: 'Copy must not summon the OS sheet');

    await drain(tester);
  });

  // Was written skipped because it caught a real bug: `_shareCodeNatively`
  // awaited `Share.share(...)` with no try/catch, fire-and-forget from
  // `onPressed`, so a platform that cannot share (no receiving app, an intent
  // the OEM cancels) escaped as an uncaught async error. The try/catch is now
  // in place, so this runs as a regression test.
  testWidgets(
      'a failing share sheet leaves the user on the sheet, not on a '
      'crash', (tester) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    interceptShareSheet(tester, fails: true);

    await tester.pumpWidget(await subject());
    await pumpFrames(tester, frames: 8);
    await openShareSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await pumpFrames(tester, frames: 8);

    expect(shareSheetCalls, hasLength(1));
    expect(tester.takeException(), isNull,
        reason: 'a platform that cannot share is not a reason to crash');
    // The code is still on screen, so the owner can fall back to Copy.
    expect(find.text(shareCode), findsOneWidget);

    await drain(tester);
  });
}
