class Env {
  Env._();

  static const environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  static bool get isProduction => environment == 'production';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://Carloss-MacBook-Pro.local:54321',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://Carloss-MacBook-Pro.local:8080',
  );

  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// App version shown in About; injected by the release build (Makefile).
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0-dev',
  );

  /// Legal pages served by the API (also registered in App Store Connect).
  static const privacyUrl = '$apiUrl/legal/privacy';
  static const termsUrl = '$apiUrl/legal/terms';

  /// Support contact used by Help & Support and the legal pages.
  static const supportEmail = 'soporte@aerolume.app';

  // RevenueCat public SDK keys (per platform). Empty disables in-app purchases
  // (billing degrades gracefully). Pass via --dart-define.
  static const revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
}
