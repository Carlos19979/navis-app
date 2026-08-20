import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/utils/measure_utils.dart';

/// Measurements were interpolated by hand everywhere — `'${x} m'`,
/// `'${x.toStringAsFixed(1)} kt'` — and `toStringAsFixed` always writes a
/// point. So a Spanish-language app printed **"12.5 m"** for a boat's length,
/// where the decimal separator is a comma.
///
/// Same gap `Money` closed for currency. These tests pin both languages,
/// because the bug is invisible in the one the tests default to.
void main() {
  group('Spanish uses a comma, and a point for thousands', () {
    test('boat length', () => expect(Measure.metres('es', 12.5), '12,5 m'));
    test('wave height', () => expect(Measure.waveHeight('es', 0.4), '0,4 m'));
    test('speed', () => expect(Measure.knots('es', 7.14, 'kt'), '7,1 kt'));
    test(
        'engine hours', () => expect(Measure.hours('es', 120, 'h'), '120,0 h'));
    test('litres past a thousand', () {
      expect(Measure.litres('es', 1607, 'L'), '1.607 L');
    });
  });

  group('English keeps the point', () {
    test('boat length', () => expect(Measure.metres('en', 12.5), '12.5 m'));
    test('litres past a thousand', () {
      expect(Measure.litres('en', 1607, 'L'), '1,607 L');
    });
  });

  group('nautical miles carry the precision the magnitude deserves', () {
    test('under ten miles the tenth matters', () {
      expect(Measure.nauticalMiles('es', 9.7, 'MN'), '9,7 MN');
    });
    test('past ten it does not', () {
      expect(Measure.nauticalMiles('es', 142.4, 'MN'), '142 MN');
    });
  });
}
