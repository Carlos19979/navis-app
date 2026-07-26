/// How long a looping animation is allowed to keep repainting.
///
/// An animation on `repeat()` with no bound drives a frame every 16 ms for as
/// long as the widget is mounted, and each of those frames also invalidates
/// any blurred layer underneath it. With the app in the foreground that is
/// pure battery drain for motion nobody is looking at any more, so every loop
/// in the app gets a budget from here.
///
/// Ideally these tokens would live next to the rest of the motion tokens in
/// `core/theme/motion.dart`.
abstract final class PulseBudget {
  /// Idle flourishes (a floating empty-state icon, a marker halo): play a
  /// couple of times to draw the eye on arrival, then rest.
  static const int decorative = 2;

  /// Things the user must not miss (an expired document, the record button):
  /// long enough to be noticed after the screen settles, still bounded.
  static const int urgent = 4;

  /// Progress indicators. They normally stop by being unmounted the moment the
  /// data arrives; this is only the stall guard for a request that never comes
  /// back, generous enough to outlast the 15 s Dio timeout plus its retries.
  static const int loadingStall = 20;

  /// `AnimationController.repeat(count:)` counts half-periods when
  /// `reverse: true`, so a there-and-back cycle is two of them. Passing an
  /// even count also guarantees the animation rests at its start value
  /// instead of freezing at the far end.
  static int reverseHalves(int cycles) => cycles * 2;
}
