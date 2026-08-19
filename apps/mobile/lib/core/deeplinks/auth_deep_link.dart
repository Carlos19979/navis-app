import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/deeplinks/join_deep_link.dart'
    show appLinksProvider;
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';

/// Whether an incoming link is the landing of a password-recovery email.
///
/// Supabase will not simply tell us. The PKCE flow — the one the app uses —
/// redirects to `<redirect_to>?code=…` and drops GoTrue's own `type=recovery`
/// on the way, so the recovery session arrives looking exactly like an
/// ordinary sign-in. That is why the app used to hand the user a session and
/// never the screen to set a new password.
///
/// So the marker in the *query* is ours: [AuthRepository.resetPassword] puts
/// it on the `redirect_to` it sends, and GoTrue preserves it and appends its
/// `code` alongside. The marker in the *fragment* is GoTrue's own, which the
/// implicit flow does keep — that is the shape a recovery mail triggered from
/// the Supabase dashboard arrives in.
bool isPasswordRecoveryUri(Uri uri) {
  if (uri.queryParameters['type'] == 'recovery') return true;
  if (uri.fragment.isEmpty) return false;
  return Uri.splitQueryString(uri.fragment)['type'] == 'recovery';
}

/// Whether an incoming link carries a GoTrue failure instead of a session,
/// which is what an expired or already-used link comes back as.
bool isFailedAuthUri(Uri uri) {
  bool carriesError(Map<String, String> params) =>
      params.containsKey('error') || params.containsKey('error_code');

  if (carriesError(uri.queryParameters)) return true;
  if (uri.fragment.isEmpty) return false;
  return carriesError(Uri.splitQueryString(uri.fragment));
}

/// Listens for incoming links and flags the ones that are a password
/// recovery, so the router can force the reset screen instead of dropping the
/// user into the app with a session they did not ask for.
///
/// Separate from the session itself, which supabase_flutter establishes off
/// the same link on its own. This only answers *why* the session arrived.
final authDeepLinkListenerProvider = Provider<void>((ref) {
  final links = ref.watch(appLinksProvider);

  void handle(Uri uri) {
    if (!isPasswordRecoveryUri(uri)) return;
    ref.read(passwordRecoveryProvider.notifier).state = true;
  }

  StreamSubscription<Uri>? subscription;
  try {
    subscription = links.uriLinkStream.listen(handle, onError: (Object e) {
      debugPrint('auth deep link stream error: $e');
    });
    // The launch link is not replayed on the stream on every platform.
    unawaited(links.getInitialLink().then((uri) {
      if (uri != null) handle(uri);
    }).catchError((Object e) {
      debugPrint('initial auth deep link unavailable: $e');
    }));
  } on Exception catch (e) {
    debugPrint('auth deep links unavailable: $e');
  }
  ref.onDispose(() => subscription?.cancel());
});
