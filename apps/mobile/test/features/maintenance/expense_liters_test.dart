import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';

void main() {
  group('Expense fuel litres', () {
    test('parses liters and derived price_per_liter', () {
      final e = Expense.fromJson({
        'id': 'e1',
        'boat_id': 'b1',
        'category': 'combustible',
        'amount': 100.0,
        'incurred_on': '2026-07-18',
        'liters': 50.0,
        'price_per_liter': 2.0,
      });
      expect(e.liters, 50.0);
      expect(e.pricePerLiter, 2.0);
    });

    test('liters/price are null when absent (non-fuel expense)', () {
      final e = Expense.fromJson({
        'id': 'e2',
        'boat_id': 'b1',
        'category': 'amarre',
        'amount': 200.0,
        'incurred_on': '2026-07-18',
      });
      expect(e.liters, isNull);
      expect(e.pricePerLiter, isNull);
    });
  });

  group('CostAnalytics fuel price', () {
    test('parses avg_price_per_liter and fuel_liters_purchased', () {
      final c = CostAnalytics.fromJson({
        'total_spend': 160.0,
        'fuel_liters_purchased': 90.0,
        'avg_price_per_liter': 1.78,
      });
      expect(c.fuelLitersPurchased, 90.0);
      expect(c.avgPricePerLiter, 1.78);
    });

    test('avg_price_per_liter is null when the API omits it', () {
      final c = CostAnalytics.fromJson({'total_spend': 50.0});
      expect(c.avgPricePerLiter, isNull);
      expect(c.fuelLitersPurchased, 0);
    });
  });
}
