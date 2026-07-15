/// Fakes for the offline layer: a test-controlled connectivity notifier and
/// a recording Dio adapter so `ApiClient.instance` never touches the network.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/network/connectivity_provider.dart';

/// Drop-in override for [connectivityProvider] whose state is flipped from
/// the test instead of the connectivity_plus platform channel.
class FakeConnectivityNotifier extends StateNotifier<bool>
    implements ConnectivityNotifier {
  FakeConnectivityNotifier([super.online = true]);

  void setOnline(bool value) => state = value;
}

/// Builds a JSON [ResponseBody] the way the Go API answers.
ResponseBody jsonResponseBody(String body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Dio adapter that records every request and answers via [handler]
/// (defaults to `200 {"data":{}}`). Install it on the singleton with
/// `ApiClient.instance.dio.httpClientAdapter = adapter`.
class RecordingHttpAdapter implements HttpClientAdapter {
  RecordingHttpAdapter({this.handler});

  FutureOr<ResponseBody> Function(RequestOptions options)? handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final respond = handler;
    if (respond == null) return jsonResponseBody('{"data":{}}');
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Polls [condition] every 20ms until it holds; fails after [timeout].
/// For fire-and-forget async work (queue replay, initial count loads).
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
