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

  /// Sends the password-recovery email. On mobile we pass a [redirectTo] deep
  /// link so the recovery link returns to the app; Supabase appends the
  /// recovery token and fires an [AuthChangeEvent.passwordRecovery] event on
  /// arrival. Reuses the already-registered `navis://login-callback` scheme.
  ///
  /// NOTE: `navis://login-callback` must be listed under Supabase Dashboard >
  /// Authentication > URL Configuration > Redirect URLs for the link to open
  /// the app.
  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : _oauthRedirect,
    );
  }

  /// Sets a new password for the currently-authenticated (recovery) session.
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Resends the signup confirmation email.
  Future<void> resendConfirmation(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }
}
