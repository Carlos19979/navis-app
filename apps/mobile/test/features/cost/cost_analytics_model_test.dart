import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/cost/data/models/cost_analytics_model.dart';

void main() {
  group('CostAnalyticsModel', () {
    test('parses the month series', () {
      final analytics = CostAnalyticsModel.fromJson({
        'months': [
          {
            'month': '2026-07',
            'by_category': {'combustible': 160.0, 'maintenance': 40},
            'fixed': 0.0,
            'variable': 200.0,
            'fuel_amount': 160.0,
            'fuel_liters': 90.0,
            'trips': 3,
            'distance_nm': 120.5,
            'fuel_l': 48.0,
            'engine_hours': 7.5,
            'hours': 22.0,
          },
        ],
      });

      final month = analytics.months.single;
      expect(month.month, '2026-07');
      expect(month.byCategory, {'combustible': 160.0, 'maintenance': 40.0});
      expect(month.total, 200);
      expect(month.fuelLiters, 90);
      expect(month.trips, 3);
      expect(month.distanceNm, 120.5);
      expect(month.engineHours, 7.5);
      expect(month.hours, 22);
      expect(month.year, 2026);
    });

    test('a boat with nothing recorded parses to an empty series', () {
      expect(CostAnalyticsModel.fromJson({'months': []}).isEmpty, isTrue);
      expect(CostAnalyticsModel.fromJson(const {}).isEmpty, isTrue);
    });

    test('missing numbers read as zero, not null', () {
      final month = CostAnalyticsModel.fromJson({
        'months': [
          {'month': '2026-01'}
        ]
      }).months.single;
      expect(month.total, 0);
      expect(month.trips, 0);
      expect(month.byCategory, isEmpty);
    });

    test('a category the owner invented survives the round trip', () {
      final month = CostAnalyticsModel.fromJson({
        'months': [
          {
            'month': '2026-02',
            'by_category': {'vela nueva': 1800.0},
            'variable': 1800.0,
          },
        ],
      }).months.single;
      expect(month.byCategory['vela nueva'], 1800);
    });
  });
}
