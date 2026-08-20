/// What a status is saying, independent of how it is drawn.
///
/// Lives in the theme layer rather than next to the chip widget because the
/// pairing of fill and ink for each tone is a design-system decision, resolved
/// by `ThemeColorsX.toneFill` / `toneInk`.
enum NavisTone { positive, caution, critical, neutral }
