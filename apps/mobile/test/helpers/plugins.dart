import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers `path_provider` with a real temporary directory.
///
/// `cached_network_image` reaches `flutter_cache_manager`, which asks
/// `path_provider` for a cache directory the moment an image provider is
/// constructed. With no plugin the call throws — and it throws as an *uncaught
/// async error*, outside `FlutterError.onError`, so the tile-noise filter
/// cannot swallow it and the test dies before the widget renders at all. That
/// is what stopped the boat photo header from appearing in a golden.
///
/// Answering the channel is better than suppressing the error: the cache
/// manager initialises, the download then fails the way it always does under
/// test, and *that* failure is the cosmetic one the filter is for.
void stubPathProvider() {
  final directory = Directory.systemTemp.createTempSync('navis_test_cache');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => directory.path,
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
}
