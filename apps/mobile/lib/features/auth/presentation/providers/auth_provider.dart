import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:navis_mobile/core/analytics/analytics_service.dart';
import 'package:navis_mobile/features/auth/data/auth_repository.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final analytics = ref.watch(analyticsProvider);
  return AuthNotifier(repository, analytics);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._analytics)
      : super(const AuthState.initial()) {
    _init();
  }

  final AuthRepository _repository;
  final AnalyticsService _analytics;
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

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _repository.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
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
