import 'package:navis_mobile/l10n/app_localizations.dart';

/// The strings Navis shows while it is *not* on screen: the Android
/// foreground-service notification behind a live GPS stream, and the
/// anchor-drag alarm.
///
/// A notifier has no `BuildContext`, and these strings are needed exactly when
/// no screen is mounted — which is why they were hardcoded in English until
/// now, in a Spanish-first app whose only visible surface while minimized is
/// that notification. The app seeds them from inside the Localizations subtree
/// (see `NavisApp.builder`), the same way [NavisDateUtils.useLocale] is seeded.
///
/// The English fallbacks only apply before the first frame has been built.
abstract final class BackgroundCopy {
  static AppLocalizations? _l;

  /// Called by the app on every build, so a locale change in Settings is
  /// picked up by the next notification the OS renders.
  static void useLocalizations(AppLocalizations l) => _l = l;

  static String get recordingTitle =>
      _l?.bgRecordingTitle ?? 'Navis is recording your trip';

  static String get recordingBody =>
      _l?.bgRecordingBody ?? 'GPS tracking active - tap to open';

  static String get anchorWatchTitle =>
      _l?.bgAnchorWatchTitle ?? 'Anchor watch active';

  static String get anchorWatchBody =>
      _l?.bgAnchorWatchBody ?? 'Watching your position - tap to open';

  static String get anchorDragTitle =>
      _l?.anchorDragTitle ?? 'Dragging anchor!';

  static String get anchorDragBody =>
      _l?.anchorDragBody ?? 'Your boat has drifted outside the swing circle.';
}
