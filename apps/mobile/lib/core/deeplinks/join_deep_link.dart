import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Invite code carried by a link the app was opened with, waiting to be used.
///
/// It is state rather than an immediate action because the link can arrive
/// before there is anyone to join *as*: tapping an invite with the app closed
/// and no session lands on the login screen. The code sits here until a screen
/// that can act on it (the boats dashboard) picks it up, and survives the trip
/// through login.
final pendingJoinCodeProvider = StateProvider<String?>((ref) => null);

/// Reads a boat invite code out of an incoming link, or null if it is not one.
///
/// Two shapes, because both exist in the wild:
/// - `navis://join?code=ABC12345` — what the app registers and what the web
///   landing page redirects to.
/// - `https://<api-host>/join?code=ABC12345` — what actually gets shared, since
///   messaging apps only linkify https.
String? joinCodeFromUri(Uri uri) {
  final isSchemeLink = uri.scheme == 'navis' && uri.host == 'join';
  final isWebLink = (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.pathSegments.length == 1 &&
      uri.pathSegments.first == 'join';
  if (!isSchemeLink && !isWebLink) return null;

  final code = uri.queryParameters['code']?.trim().toUpperCase();
  if (code == null || code.isEmpty) return null;
  return code;
}

/// Listens for incoming links for as long as the app is running.
///
/// Watched from the app root next to the other auth/lifecycle listeners. Kept
/// out of `main()` so it can be exercised with an injected [AppLinks] and so a
/// platform that throws on link setup cannot stop the app from starting.
final joinDeepLinkListenerProvider = Provider<void>((ref) {
  final links = ref.watch(appLinksProvider);

  void handle(Uri uri) {
    final code = joinCodeFromUri(uri);
    if (code == null) return;
    ref.read(pendingJoinCodeProvider.notifier).state = code;
  }

  StreamSubscription<Uri>? subscription;
  try {
    subscription = links.uriLinkStream.listen(handle, onError: (Object e) {
      debugPrint('deep link stream error: $e');
    });
    // The launch link is not replayed on the stream on every platform.
    unawaited(links.getInitialLink().then((uri) {
      if (uri != null) handle(uri);
    }).catchError((Object e) {
      debugPrint('initial deep link unavailable: $e');
    }));
  } on Exception catch (e) {
    debugPrint('deep links unavailable: $e');
  }
  ref.onDispose(() => subscription?.cancel());
});

/// Overridden in tests with a fake.
final appLinksProvider = Provider<AppLinks>((ref) => AppLinks());
