import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/models/analytics_period.dart';

void main() {
  group('contains', () {
    test('all time contains everything', () {
      const period = AnalyticsPeriod.allTime();

      expect(period.contains(DateTime(2019, 1, 12)), isTrue);
      expect(period.contains(DateTime(2026, 12, 31)), isTrue);
      expect(period.isAllTime, isTrue);
    });

    test('a year contains only that year', () {
      const period = AnalyticsPeriod.year(2025);

      expect(period.contains(DateTime(2025, 1, 14)), isTrue);
      expect(period.contains(DateTime(2025, 12, 31, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 1, 14)), isFalse);
      expect(period.contains(DateTime(2024, 12, 31)), isFalse);
    });

    test('a month contains only that month of that year', () {
      const period = AnalyticsPeriod.month(2025, 7);

      expect(period.contains(DateTime(2025, 7, 15)), isTrue);
      expect(period.contains(DateTime(2025, 8, 3)), isFalse);
      expect(period.contains(DateTime(2024, 7, 15)), isFalse);
    });
  });

  group('containsMonthKey', () {
    test('all time takes every key', () {
      const period = AnalyticsPeriod.allTime();
      expect(period.containsMonthKey('2019-01'), isTrue);
      expect(period.containsMonthKey('2026-12'), isTrue);
    });

    test('a year takes its own twelve keys', () {
      const period = AnalyticsPeriod.year(2025);
      expect(period.containsMonthKey('2025-01'), isTrue);
      expect(period.containsMonthKey('2025-12'), isTrue);
      expect(period.containsMonthKey('2026-01'), isFalse);
      // The year is matched as a whole segment, not a prefix: 2025 must not
      // swallow 20250 or 202.
      expect(period.containsMonthKey('2251-01'), isFalse);
    });

    test('a month takes exactly one key, zero-padded', () {
      const period = AnalyticsPeriod.month(2025, 7);
      expect(period.containsMonthKey('2025-07'), isTrue);
      expect(period.containsMonthKey('2025-7'), isFalse);
      expect(period.containsMonthKey('2025-08'), isFalse);
    });
  });

  group('previous', () {
    test('all time has nothing before it', () {
      expect(const AnalyticsPeriod.allTime().previous, isNull);
    });

    test('a year steps back a year', () {
      expect(
        const AnalyticsPeriod.year(2026).previous,
        const AnalyticsPeriod.year(2025),
      );
    });

    test('a month steps back a month', () {
      expect(
        const AnalyticsPeriod.month(2026, 5).previous,
        const AnalyticsPeriod.month(2026, 4),
      );
    });

    test('january steps back to december of the year before', () {
      expect(
        const AnalyticsPeriod.month(2026, 1).previous,
        const AnalyticsPeriod.month(2025, 12),
      );
    });
  });

  test('withMonth switches between a month and the whole year', () {
    const year = AnalyticsPeriod.year(2025);

    expect(year.withMonth(3), const AnalyticsPeriod.month(2025, 3));
    expect(year.withMonth(3).withMonth(null), const AnalyticsPeriod.year(2025));
  });
}
