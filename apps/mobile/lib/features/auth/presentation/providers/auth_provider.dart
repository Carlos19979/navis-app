import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// True while a password-recovery deep link has been opened and the user has
/// not yet set a new password. The router consumes this to force the
/// `/reset-password` screen so a recovery session is not treated as a normal
/// login that bounces to `/boats`.
///
/// **Persisted**, and that is the whole point. The recovery link hands the app
/// a real session, which supabase_flutter writes to disk like any other. When
/// this lived in memory, leaving the app on the reset screen and coming back
/// dropped the flag while the session survived — so the app opened straight
/// into the boat list and the password was never changed. Whoever opened that
/// email ended up simply logged in.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
  PasswordRecoveryNotifier.new,
);

/// Key under which the pending recovery survives a restart.
const _keyPasswordRecovery = 'auth_password_recovery_pending';

class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_keyPasswordRecovery) ?? false;
  }

  /// A recovery link was opened: hold the user on the reset screen until the
  /// password is actually set, however many times the app is restarted.
  void begin() => _set(true);

  /// The recovery is over — the password was changed, the user signed out, or
  /// they signed in normally, which all mean there is nothing pending.
  void complete() => _set(false);

  void _set(bool pending) {
    if (state == pending) return;
    ref.read(sharedPreferencesProvider).setBool(_keyPasswordRecovery, pending);
    state = pending;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final analytics = ref.watch(analyticsProvider);
  return AuthNotifier(repository, analytics, ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._analytics, this._ref)
      : super(const AuthState.initial()) {
    _init();
  }

  final AuthRepository _repository;
  final AnalyticsService _analytics;
  final Ref _ref;
  StreamSubscription<supa.AuthState>? _authSubscription;

  void _init() {
    final session = _repository.currentSession;
    if (session != null && !session.isExpired) {
      state = AuthState.authenticated(session.user);
    } else {
      state = const AuthState.unauthenticated();
    }

    _authSubscription = _repository.onAuthStateChange().listen((authState) {
      final session = authState.session;
      if (session != null) {
        state = AuthState.authenticated(session.user);
      } else if (state.status != AuthStatus.pendingEmailConfirmation) {
        // Supabase fires a session-less event right after signUp when email
        // confirmation is on — don't clobber the "check your email" state.
        state = const AuthState.unauthenticated();
      }
    });
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _repository.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Signing in with a password settles any recovery left half-done: the
        // flag is persisted, so without this a link opened and abandoned would
        // keep bouncing every later login onto the reset screen.
        _ref.read(passwordRecoveryProvider.notifier).complete();
        _analytics.trackLogin(response.user!.id);
        state = AuthState.authenticated(response.user);
      } else {
        state = const AuthState.unauthenticated(
          errorMessage: 'Login failed. Please try again.',
        );
      }
    } on supa.AuthException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _repository.signUp(
        email: email,
        password: password,
      );
      if (response.user != null && response.session != null) {
        _analytics.trackSignup(response.user!.id);
        state = AuthState.authenticated(response.user);
      } else if (response.user != null) {
        // Email confirmations are on: user exists but there is no session
        // until the link in the email is opened.
        _analytics.trackSignup(response.user!.id);
        state = AuthState.pendingEmailConfirmation(email);
      } else {
        state = const AuthState.unauthenticated(
          errorMessage: 'Registration failed. Please try again.',
        );
      }
    } on supa.AuthException catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.message);
    }
  }

  /// Resends the signup confirmation email.
  /// Saves the user's display name and refreshes the session user so anything
  /// reading it (the profile header, the avatar initial) updates immediately.
  Future<void> updateDisplayName(String name) async {
    await _repository.updateDisplayName(name);
    final user = _repository.currentUser;
    if (user != null) state = AuthState.authenticated(user);
  }

  Future<void> resendConfirmationEmail() async {
    final email = state.pendingEmail;
    if (email == null) return;
    await _repository.resendConfirmation(email);
  }

  /// Leaves the pending-confirmation state (back to login).
  void backToLogin() {
    if (state.status == AuthStatus.pendingEmailConfirmation) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> logout() async {
    _ref.read(passwordRecoveryProvider.notifier).complete();
    _analytics.reset();
    await _repository.signOut();
    state = const AuthState.unauthenticated();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
