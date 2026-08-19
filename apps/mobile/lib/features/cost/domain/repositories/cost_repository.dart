import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';

/// Reads a boat's cost intelligence (Pro).
abstract interface class CostRepository {
  Future<CostAnalytics> getForBoat(String boatId);
}
