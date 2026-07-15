import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scoped FlutterError filter for map screens (see the chart spike): tile
/// fetches resolve through cached_network_image, whose flutter_cache_manager
/// backend hits path_provider/HTTP; in tests that surfaces
/// MissingPluginException and image-load errors through FlutterError. They
/// are cosmetic, so swallow only those and forward everything else. The
/// original handler is restored via [addTearDown].
void installTileNoiseFilter() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    const tolerated = [
      'MissingPluginException',
      'HTTP request failed',
      'NetworkImage',
      'CachedNetworkImageProvider',
      'HttpException',
      'SocketException',
      'Failed host lookup',
      'Connection refused',
      'Connection closed',
      "Couldn't download or retrieve file",
      'HttpExceptionWithStatus',
    ];
    if (tolerated.any(message.contains)) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}
