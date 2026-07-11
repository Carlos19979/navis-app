import 'package:supabase_flutter/supabase_flutter.dart' show User;

enum AuthStatus {
  authenticated,
  unauthenticated,
  loading,

  /// Signed up but the email is not confirmed yet: there is a user but no
  /// session. The app shows the "check your email" screen until the user
  /// confirms and logs in.
  pendingEmailConfirmation,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.pendingEmail,
  });

  const AuthState.initial()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null,
        pendingEmail = null;

  const AuthState.authenticated(this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null,
        pendingEmail = null;

  const AuthState.unauthenticated({this.errorMessage})
      : status = AuthStatus.unauthenticated,
        user = null,
        pendingEmail = null;

  const AuthState.pendingEmailConfirmation(this.pendingEmail)
      : status = AuthStatus.pendingEmailConfirmation,
        user = null,
        errorMessage = null;

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// Email awaiting confirmation (set when status is pendingEmailConfirmation).
  final String? pendingEmail;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    String? pendingEmail,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingEmail: pendingEmail ?? this.pendingEmail,
    );
  }
}
