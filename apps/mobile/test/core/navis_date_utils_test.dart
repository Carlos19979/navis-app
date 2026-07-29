import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/utils/navis_date_utils.dart';

import '../helpers/helpers.dart';

/// `daysUntil` used to subtract two *local* midnights, which span 23 or 25 hours
/// when the clocks change in between; `.inDays` truncates, so a date exactly N
/// calendar days out came back as N-1 across a spring-forward. It decides the
/// expiry badge colour and the "N days remaining" copy, and it silently broke
/// the document tests at midnight on 30 July 2026 — the 120-day window had just
/// grown to include the October change.
void main() {
  group('daysUntil', () {
    // The invariant every caller relies on, across windows long enough to
    // contain a DST transition whatever today happens to be.
    test('counts calendar days, DST transitions included', () {
      for (final days in [0, 1, 5, 29, 30, 60, 90, 91, 120, 180, 240, 365]) {
        final date = makeDocument(daysUntilExpiry: days).expiryDate;

        expect(
          NavisDateUtils.daysUntil(date),
          days,
          reason: '$days days out came back as '
              '${NavisDateUtils.daysUntil(date)}',
        );
      }
    });

    test('an expired document counts negative', () {
      for (final days in [-1, -30, -200]) {
        final date = makeDocument(daysUntilExpiry: days).expiryDate;

        expect(NavisDateUtils.daysUntil(date), days);
      }
    });

    test('a UTC timestamp is read as its local date', () {
      // Expiry dates arrive from the API as UTC instants.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12).toUtc();

      expect(NavisDateUtils.daysUntil(today), 0);
    });
  });

  group('status thresholds follow daysUntil', () {
    test('the buckets line up with the canonical thresholds', () {
      DocExpiryStatus statusIn(int days) => NavisDateUtils.statusFor(
          makeDocument(daysUntilExpiry: days).expiryDate);

      expect(statusIn(-1), DocExpiryStatus.expired);
      expect(statusIn(0), DocExpiryStatus.critical);
      expect(statusIn(NavisDateUtils.expiryCriticalDays),
          DocExpiryStatus.critical);
      expect(statusIn(NavisDateUtils.expiryCriticalDays + 1),
          DocExpiryStatus.warning);
      expect(
          statusIn(NavisDateUtils.expiryWarningDays), DocExpiryStatus.warning);
      expect(
          statusIn(NavisDateUtils.expiryWarningDays + 1), DocExpiryStatus.ok);
    });
  });
}
