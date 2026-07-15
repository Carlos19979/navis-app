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
