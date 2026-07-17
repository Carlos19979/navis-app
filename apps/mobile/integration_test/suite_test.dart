import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'journeys/j01_auth.dart';
import 'journeys/j02_boats.dart';
import 'journeys/j03_documents.dart';
import 'journeys/j04_maintenance.dart';
import 'journeys/j05_logbook.dart';
import 'journeys/j06_charts_weather.dart';
import 'journeys/j07_community.dart';
import 'journeys/j08_profile_teardown.dart';
import 'journeys/j09_shared_boat.dart';

/// Full E2E journey sweep against the real local stack. Journeys are
/// order-dependent by design: J01 registers the per-run user, later journeys
/// enrich its data, and (in the final phase) the last journey deletes it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  j01Auth();
  j02Boats();
  j03Documents();
  j04Maintenance();
  j05Logbook();
  j06ChartsWeather();
  j07Community();
  // J09 runs before J08: it needs user A alive (J08 deletes the account).
  j09SharedBoat();
  j08ProfileTeardown();
}
