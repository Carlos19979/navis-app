import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _initialized = false;

/// Initializes Supabase against a dummy local URL so code paths that touch
/// `Supabase.instance` (auth/session lookups) work in widget tests. Safe to
/// call from every test; only the first call does the work.
Future<void> initFakeSupabase() async {
  if (_initialized) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'http://localhost:54321',
    anonKey: 'test-anon-key',
  );
  _initialized = true;
}

/// Installs a fake authenticated session so code that reads
/// `Supabase.instance.client.auth.currentUser` works in widget tests.
///
/// Works fully offline: `recoverSession` only hits the network when the
/// access token is expired, and the crafted JWT expires in 2100.
Future<void> signInFakeUser({String userId = 'user-1'}) async {
  await initFakeSupabase();
  await Supabase.instance.client.auth.recoverSession(jsonEncode({
    'access_token': _fakeJwt(userId),
    'token_type': 'bearer',
    'refresh_token': 'fake-refresh-token',
    'expires_in': 3600,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'email': 'test@navis.app',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
    },
  }));
}

/// An unsigned JWT whose `exp` (year 2100) keeps the session non-expired.
String _fakeJwt(String sub) {
  String enc(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  final header = enc({'alg': 'HS256', 'typ': 'JWT'});
  final payload = enc({
    'sub': sub,
    'exp': 4102444800, // 2100-01-01
    'role': 'authenticated',
  });
  return '$header.$payload.fake-signature';
}
