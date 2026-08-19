import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';

class AuthRepository {
  GoTrueClient get _auth => supabaseClient.auth;

  /// Deep-link the OAuth provider redirects back to. Must match the URL scheme
  /// registered in iOS Info.plist / Android manifest and the Supabase provider
  /// redirect allow-list.
  static const _oauthRedirect = 'navis://login-callback';

  Session? get currentSession => _auth.currentSession;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> onAuthStateChange() {
    return _auth.onAuthStateChange;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _auth.signUp(email: email, password: password);
  }

  /// Starts the Google OAuth flow (opens a browser; session arrives via the
  /// redirect deep link and onAuthStateChange).
  Future<bool> signInWithGoogle() {
    return _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : _oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Starts the Apple OAuth flow.
  Future<bool> signInWithApple() {
    return _auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? null : _oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Where a recovery link comes back to. Same registered scheme as OAuth,
  /// plus a marker of our own — because GoTrue does not keep its.
  ///
  /// The app is on the PKCE flow, where the verified link redirects to
  /// `<redirect_to>?code=…` and `type=recovery` is dropped along the way. The
  /// arriving session is then indistinguishable from a normal sign-in, so the
  /// app has no reason to show the "set a new password" screen and silently
  /// lands the user in the boat list instead. GoTrue *does* preserve whatever
  /// query the redirect already carries and appends `code` next to it, so the
  /// marker survives the round trip.
  ///
  /// NOTE: this exact value must be allow-listed under Supabase Dashboard >
  /// Authentication > URL Configuration > Redirect URLs — a `?*` wildcard
  /// entry, since it carries a query. An unlisted redirect is not rejected:
  /// GoTrue silently falls back to the project's Site URL.
  static const _recoveryRedirect = 'navis://login-callback?type=recovery';

  /// Sends the password-recovery email.
  ///
  /// Answers the same whether or not the address belongs to an account —
  /// Supabase will not say, so that the form cannot be used to test which
  /// emails are registered. Callers must not claim a mail was sent.
  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : _recoveryRedirect,
    );
  }

  /// Sets a new password for the currently-authenticated (recovery) session.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Stores the user's chosen display name in their auth metadata.
  ///
  /// Email signup captures no name at all, so without this there is nothing to
  /// show on the profile but the email. Written under `display_name`, the first
  /// key [displayNameFromMetadata] looks at, so it wins over anything an OAuth
  /// provider supplied.
  Future<void> updateDisplayName(String name) async {
    await _auth.updateUser(
      UserAttributes(data: {'display_name': name.trim()}),
    );
  }

  /// Resends the signup confirmation email.
  Future<void> resendConfirmation(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }
}
