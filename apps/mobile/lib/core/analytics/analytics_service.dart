import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/config/env.dart';

final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  bool get _enabled => !Env.isDevelopment;

  void identify(String userId, {Map<String, dynamic>? properties}) {
    if (!_enabled) return;
    // PostHog: Posthog().identify(userId: userId, userProperties: properties);
  }

  void track(String event, {Map<String, dynamic>? properties}) {
    if (!_enabled) return;
    // PostHog: Posthog().capture(eventName: event, properties: properties);
  }

  void screen(String name, {Map<String, dynamic>? properties}) {
    if (!_enabled) return;
    // PostHog: Posthog().screen(screenName: name, properties: properties);
  }

  void reset() {
    if (!_enabled) return;
    // PostHog: Posthog().reset();
  }

  void trackSignup(String userId) =>
      track('signup', properties: {'user_id': userId});

  void trackLogin(String userId) =>
      track('login', properties: {'user_id': userId});

  void trackBoatCreated(String boatId) =>
      track('boat_created', properties: {'boat_id': boatId});

  void trackDocumentCreated(String docId, String boatId) => track(
        'document_created',
        properties: {'document_id': docId, 'boat_id': boatId},
      );

  void trackTripStarted(String tripId, String boatId) => track(
        'trip_started',
        properties: {'trip_id': tripId, 'boat_id': boatId},
      );

  void trackTripCompleted(String tripId, String boatId) => track(
        'trip_completed',
        properties: {'trip_id': tripId, 'boat_id': boatId},
      );
}
