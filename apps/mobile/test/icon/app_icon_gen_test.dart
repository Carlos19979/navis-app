@Tags(['golden'])
library;

// App icon generator for Navis.
//
// Renders two 1024x1024 PNG icon variants directly with the Flutter engine
// (PictureRecorder + Canvas -> Picture.toImage -> PNG bytes) and writes them
// to build/icon_gen/. This is NOT the golden harness; it just produces files.
//
// Run: flutter test test/icon/app_icon_gen_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double kSize = 1024;

// Palette.
const Color navyTopLeft = Color(0xFF1B2A4A);
const Color navyBottomRight = Color(0xFF0F1A30);
const Color navyDeep = Color(0xFF12203B);
const Color cyan = Color(0xFF4DA8DA);
const Color cyanLight = Color(0xFF8FD0F0);
const Color white = Color(0xFFFFFFFF);

/// Paints the shared full-bleed background: diagonal navy gradient plus a
/// subtle radial glow centered slightly above the middle behind the mark.
void _paintBackground(Canvas canvas) {
  final Rect full = const Rect.fromLTWH(0, 0, kSize, kSize);

  // Diagonal gradient top-left -> bottom-right.
  final Paint bg = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [navyTopLeft, navyDeep, navyBottomRight],
      stops: [0.0, 0.55, 1.0],
    ).createShader(full);
  canvas.drawRect(full, bg);

  // Subtle radial glow behind the mark.
  final Paint glow = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(kSize * 0.5, kSize * 0.46),
      kSize * 0.52,
      [
        cyan.withValues(alpha: 0.18),
        cyan.withValues(alpha: 0.06),
        cyan.withValues(alpha: 0.0),
      ],
      [0.0, 0.5, 1.0],
    );
  canvas.drawRect(full, glow);
}

/// Variant A: clean sailboat.
/// - A tall white mainsail (right of mast) + a smaller cyan jib (left of mast),
///   both triangles rising from a short vertical mast.
/// - Two stylised cyan wave strokes below the hull.
void _paintSailboat(Canvas canvas) {
  _paintBackground(canvas);

  const double cx = kSize * 0.5;

  // Vertical layout anchors.
  const double mastTop = kSize * 0.185; // top of sails
  const double sailBottom = kSize * 0.605; // where sails meet the deck line
  const double mastX = cx + kSize * 0.012; // mast slightly right of center

  // --- Mast ---
  final Paint mastPaint = Paint()
    ..color = white
    ..strokeWidth = kSize * 0.014
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    Offset(mastX, mastTop - kSize * 0.005),
    Offset(mastX, sailBottom),
    mastPaint,
  );

  // --- Mainsail: white triangle to the right of the mast ---
  final Path mainsail = Path()
    ..moveTo(mastX + kSize * 0.008, mastTop) // apex at mast top
    ..lineTo(mastX + kSize * 0.008, sailBottom) // down the mast (foot start)
    ..lineTo(mastX + kSize * 0.235, sailBottom) // out to the clew
    ..close();
  // Gentle vertical gradient for depth on the mainsail.
  final Paint mainPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [white, Color(0xFFE8F4FB)],
    ).createShader(
      Rect.fromLTWH(mastX, mastTop, kSize * 0.235, sailBottom - mastTop),
    );
  canvas.drawPath(mainsail, mainPaint);

  // --- Jib: smaller cyan triangle to the left of the mast ---
  final Path jib = Path()
    ..moveTo(mastX - kSize * 0.012, mastTop + kSize * 0.055) // apex a bit lower
    ..lineTo(mastX - kSize * 0.012, sailBottom) // down near the mast
    ..lineTo(mastX - kSize * 0.165, sailBottom) // out to the tack
    ..close();
  final Paint jibPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [cyanLight, cyan],
    ).createShader(
      Rect.fromLTWH(
        mastX - kSize * 0.165,
        mastTop,
        kSize * 0.16,
        sailBottom - mastTop,
      ),
    );
  canvas.drawPath(jib, jibPaint);

  // --- Hull: a shallow white curved boat sitting on the deck line ---
  const double hullTop = sailBottom + kSize * 0.006;
  final Path hull = Path()
    ..moveTo(cx - kSize * 0.235, hullTop)
    ..lineTo(cx + kSize * 0.235, hullTop)
    ..quadraticBezierTo(
      cx + kSize * 0.16,
      hullTop + kSize * 0.085,
      cx,
      hullTop + kSize * 0.085,
    )
    ..quadraticBezierTo(
      cx - kSize * 0.16,
      hullTop + kSize * 0.085,
      cx - kSize * 0.235,
      hullTop,
    )
    ..close();
  canvas.drawPath(hull, Paint()..color = white);

  // --- Wave strokes below the boat (cyan) ---
  final Paint wavePaint = Paint()
    ..color = cyan
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSize * 0.032
    ..strokeCap = StrokeCap.round;

  const double waveY1 = kSize * 0.76;
  final Path wave1 = Path()
    ..moveTo(cx - kSize * 0.30, waveY1)
    ..cubicTo(
      cx - kSize * 0.14, waveY1 - kSize * 0.055,
      cx - kSize * 0.06, waveY1 + kSize * 0.055,
      cx + kSize * 0.06, waveY1,
    )
    ..cubicTo(
      cx + kSize * 0.16, waveY1 - kSize * 0.045,
      cx + kSize * 0.22, waveY1 + kSize * 0.02,
      cx + kSize * 0.30, waveY1 - kSize * 0.01,
    );
  canvas.drawPath(wave1, wavePaint);

  final Paint wavePaint2 = Paint()
    ..color = cyanLight.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSize * 0.026
    ..strokeCap = StrokeCap.round;
  const double waveY2 = kSize * 0.845;
  final Path wave2 = Path()
    ..moveTo(cx - kSize * 0.24, waveY2)
    ..cubicTo(
      cx - kSize * 0.10, waveY2 - kSize * 0.045,
      cx - kSize * 0.02, waveY2 + kSize * 0.045,
      cx + kSize * 0.10, waveY2,
    )
    ..cubicTo(
      cx + kSize * 0.17, waveY2 - kSize * 0.035,
      cx + kSize * 0.20, waveY2 + kSize * 0.015,
      cx + kSize * 0.24, waveY2,
    );
  canvas.drawPath(wave2, wavePaint2);
}

/// Variant B: compass rose / navigation star.
/// - A large sharp 4-point star (N/E/S/W) with a smaller 4-point star rotated
///   45deg (NE/SE/SW/NW) behind it, plus a thin cyan ring, centered.
void _paintCompass(Canvas canvas) {
  _paintBackground(canvas);

  const double cx = kSize * 0.5;
  const double cy = kSize * 0.5;

  // Thin ring.
  final Paint ring = Paint()
    ..color = cyan.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSize * 0.012;
  canvas.drawCircle(const Offset(cx, cy), kSize * 0.345, ring);

  // Inner tick ring (very subtle, adds "instrument" feel).
  final Paint ring2 = Paint()
    ..color = cyan.withValues(alpha: 0.30)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kSize * 0.006;
  canvas.drawCircle(const Offset(cx, cy), kSize * 0.315, ring2);

  const double majorLen = kSize * 0.31; // reach of primary points
  const double minorLen = kSize * 0.185; // reach of diagonal points
  const double waist = kSize * 0.052; // half-width of star arms at center

  // --- Minor (diagonal) 4-point star, drawn first so it sits behind ---
  final Path minorStar = _fourPointStar(cx, cy, minorLen, waist * 0.72,
      rotation: math.pi / 4);
  canvas.drawPath(minorStar, Paint()..color = cyan.withValues(alpha: 0.85));

  // --- Major 4-point star (N/E/S/W) ---
  // Split each cardinal spike into two halves so we can two-tone the needle:
  // the northern spike is cyan->white, the rest cyan.
  final Path majorStar = _fourPointStar(cx, cy, majorLen, waist);

  // Base fill cyan.
  canvas.drawPath(majorStar, Paint()..color = cyan);

  // Overlay: the top (north) needle in a cyan->white gradient for a lit tip.
  final Path northSpike = Path()
    ..moveTo(cx, cy - majorLen)
    ..lineTo(cx + waist, cy)
    ..lineTo(cx - waist, cy)
    ..close();
  final Paint northPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [white, cyanLight, cyan],
      stops: [0.0, 0.45, 1.0],
    ).createShader(
      Rect.fromLTWH(cx - waist, cy - majorLen, waist * 2, majorLen),
    );
  canvas.drawPath(northSpike, northPaint);

  // Give the west/east spikes a subtle lighter left edge for dimensional feel:
  // draw thin white highlights along the "left" facet of each cardinal spike.
  final Paint facet = Paint()
    ..color = white.withValues(alpha: 0.16)
    ..style = PaintingStyle.fill;
  // East spike left facet.
  final Path eastFacet = Path()
    ..moveTo(cx + majorLen, cy)
    ..lineTo(cx, cy - waist)
    ..lineTo(cx, cy)
    ..close();
  canvas.drawPath(eastFacet, facet);
  // South spike left facet.
  final Path southFacet = Path()
    ..moveTo(cx, cy + majorLen)
    ..lineTo(cx - waist, cy)
    ..lineTo(cx, cy)
    ..close();
  canvas.drawPath(southFacet, facet);
  // West spike top facet (lighter).
  final Path westFacet = Path()
    ..moveTo(cx - majorLen, cy)
    ..lineTo(cx, cy - waist)
    ..lineTo(cx, cy)
    ..close();
  canvas.drawPath(westFacet, Paint()..color = white.withValues(alpha: 0.10));

  // --- Center hub ---
  canvas.drawCircle(const Offset(cx, cy), waist * 0.9, Paint()..color = navyDeep);
  canvas.drawCircle(
    const Offset(cx, cy),
    waist * 0.9,
    Paint()
      ..color = white
      ..style = PaintingStyle.stroke
      ..strokeWidth = kSize * 0.010,
  );
  canvas.drawCircle(const Offset(cx, cy), waist * 0.30, Paint()..color = white);
}

/// Builds a 4-point star (concave diamond) centered at (cx,cy).
/// [len] is the spike reach from center; [waist] is the half-width where arms
/// meet the diagonal inner vertices. Optional [rotation] in radians.
Path _fourPointStar(double cx, double cy, double len, double waist,
    {double rotation = 0}) {
  // Points in order: N, inner-NE, E, inner-SE, S, inner-SW, W, inner-NW.
  final double inner = waist * 1.0;
  final List<Offset> pts = [
    Offset(0, -len), // N
    Offset(inner, -inner), // NE inner
    Offset(len, 0), // E
    Offset(inner, inner), // SE inner
    Offset(0, len), // S
    Offset(-inner, inner), // SW inner
    Offset(-len, 0), // W
    Offset(-inner, -inner), // NW inner
  ];
  final double cosr = math.cos(rotation);
  final double sinr = math.sin(rotation);
  final Path p = Path();
  for (int i = 0; i < pts.length; i++) {
    final double x = pts[i].dx * cosr - pts[i].dy * sinr + cx;
    final double y = pts[i].dx * sinr + pts[i].dy * cosr + cy;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  p.close();
  return p;
}

Future<void> _writeIcon(String name, void Function(Canvas) paint) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, kSize, kSize),
  );
  paint(canvas);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(kSize.toInt(), kSize.toInt());
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  expect(bytes, isNotNull);

  final Directory outDir =
      Directory('build/icon_gen')..createSync(recursive: true);
  final File out = File('${outDir.path}/$name');
  out.writeAsBytesSync(bytes!.buffer.asUint8List());
  // Sanity: dimensions.
  expect(image.width, 1024);
  expect(image.height, 1024);
  // ignore: avoid_print
  print('Wrote ${out.absolute.path} (${image.width}x${image.height})');
}

void main() {
  test('generate Navis app icons', () async {
    await _writeIcon('navis_icon_a.png', _paintSailboat);
    await _writeIcon('navis_icon_b.png', _paintCompass);
  });
}
