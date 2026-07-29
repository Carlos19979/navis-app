import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points sqflite at a temp directory of this test file's own.
///
/// Call it from `setUpAll` in **every** file that touches `LocalDatabase`.
///
/// `flutter test` runs test files in parallel processes and `LocalDatabase`
/// always opens `navis_cache.db` from the default databases path, so two files
/// running at the same time open — and `deleteDatabase` — the same file. That is
/// `SqliteException(5898): disk I/O error` on COMMIT, which is exactly the flake
/// that turned the check suite red on `main` and made Railway **skip a
/// production deploy** (the code was fine; the deploy just never happened).
///
/// Two files had hand-rolled this isolation and four had not. A helper so the
/// next file cannot forget.
///
/// The directory is left behind on purpose: the OS reclaims its temp dir, and a
/// teardown cannot be registered from `setUpAll` without fighting the harness.
Future<void> useIsolatedDatabase(String suite) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await databaseFactory.setDatabasesPath(
    Directory.systemTemp.createTempSync('navis_${suite}_test').path,
  );
}
