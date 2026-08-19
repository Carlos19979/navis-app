import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/deeplinks/auth_deep_link.dart';

void main() {
  group('isPasswordRecoveryUri', () {
    // The shape the app's own flow produces. Captured against the live
    // project: GoTrue drops its `type=recovery` in the PKCE flow but keeps
    // the query we put on `redirect_to`, and appends `code` next to it.
    test('recognises the PKCE landing, marked by us', () {
      expect(
        isPasswordRecoveryUri(
          Uri.parse('navis://login-callback?type=recovery&code=abc123'),
        ),
        isTrue,
      );
    });

    // What a recovery mail triggered from the Supabase dashboard produces:
    // the implicit flow, which does keep GoTrue's own marker, in the fragment.
    test('recognises the implicit landing, marked by GoTrue', () {
      expect(
        isPasswordRecoveryUri(
          Uri.parse('navis://login-callback'
              '#access_token=xyz&refresh_token=rst&type=recovery'),
        ),
        isTrue,
      );
    });

    // Same landing, one tap earlier: the web page the mail actually opens.
    test('recognises it on the https landing page too', () {
      expect(
        isPasswordRecoveryUri(
          Uri.parse('https://navis-app-production.up.railway.app/auth/callback'
              '?code=abc123&type=recovery'),
        ),
        isTrue,
      );
    });

    // A plain sign-in must NOT be diverted to the reset-password screen.
    test('leaves every other link alone', () {
      for (final uri in [
        'navis://login-callback?code=abc123', // OAuth, or a signup confirm
        'navis://login-callback#access_token=xyz&type=signup',
        'navis://join?code=EZHT4CNG',
        'navis://login-callback',
        'https://example.com/',
      ]) {
        expect(isPasswordRecoveryUri(Uri.parse(uri)), isFalse, reason: uri);
      }
    });
  });

  group('isFailedAuthUri', () {
    // The single most common failure: the link was already used, or it sat in
    // the inbox for more than an hour.
    test('recognises an expired link in the fragment', () {
      expect(
        isFailedAuthUri(
          Uri.parse('navis://login-callback'
              '#error=access_denied&error_code=otp_expired'
              '&error_description=Email+link+is+invalid+or+has+expired'),
        ),
        isTrue,
      );
    });

    test('recognises one in the query', () {
      expect(
        isFailedAuthUri(
          Uri.parse('navis://login-callback?error=server_error'),
        ),
        isTrue,
      );
    });

    test('a working link is not a failure', () {
      for (final uri in [
        'navis://login-callback?type=recovery&code=abc123',
        'navis://login-callback#access_token=xyz&type=recovery',
        'navis://login-callback',
      ]) {
        expect(isFailedAuthUri(Uri.parse(uri)), isFalse, reason: uri);
      }
    });
  });
}
