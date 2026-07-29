import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/deeplinks/join_deep_link.dart';

void main() {
  group('joinCodeFromUri', () {
    test('reads the code from the app scheme', () {
      expect(
        joinCodeFromUri(Uri.parse('navis://join?code=EZHT4CNG')),
        'EZHT4CNG',
      );
    });

    // What actually gets shared, since messaging apps only linkify https.
    test('reads the code from the web invite link', () {
      expect(
        joinCodeFromUri(
          Uri.parse('https://navis-app-production.up.railway.app/join'
              '?code=EZHT4CNG'),
        ),
        'EZHT4CNG',
      );
    });

    test('upper-cases a hand-typed code', () {
      expect(
          joinCodeFromUri(Uri.parse('navis://join?code=ezht4cng')), 'EZHT4CNG');
    });

    test('ignores links that are not invites', () {
      for (final uri in [
        'navis://login-callback?code=abc', // Supabase OAuth — not ours
        'https://example.com/joinery?code=EZHT4CNG',
        'https://example.com/boats/1/join?code=EZHT4CNG', // deeper path
        'navis://join', // no code
        'navis://join?code=', // empty code
        'https://example.com/',
      ]) {
        expect(
          joinCodeFromUri(Uri.parse(uri)),
          isNull,
          reason: uri,
        );
      }
    });
  });
}
