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
    return _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _auth.signUp(
      email: email,
      password: password,
    );
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

  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email);
  }
}
