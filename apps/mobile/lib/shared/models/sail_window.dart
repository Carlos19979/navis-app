/// How good the conditions are for going out.
enum SailWindow {
  good,
  moderate,
  adverse;

  /// Judges wind (knots) and significant wave height (metres).
  ///
  /// The thresholds are the ones the weather screen has always used; they moved
  /// here because the answer is needed in two places — on the forecast, where
  /// it explains the numbers, and on Today, where it is the reason someone
  /// opened the app. Pure doubles in, so a shared helper does not have to know
  /// about the weather feature's entities.
  static SailWindow evaluate({
    required double windKnots,
    required double waveMetres,
  }) {
    if (windKnots <= 12 && waveMetres <= 0.5) return SailWindow.good;
    if (windKnots <= 20 && waveMetres <= 1.2) return SailWindow.moderate;
    return SailWindow.adverse;
  }
}
