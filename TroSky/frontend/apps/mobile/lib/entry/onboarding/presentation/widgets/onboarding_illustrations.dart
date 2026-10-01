import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:trosky_ui/trosky_ui.dart';

/// The onboarding illustrations, `OnboardIllustration1/2/3` in
/// PassengerDesigns.tsx, drawn element by element in the SVG's coordinates
/// and order. Their text is part of the artwork, so it is drawn here rather
/// than translated.
///
/// Decorative: hidden from screen readers. On a short screen the drawing
/// shrinks to fit instead of overflowing.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration.page1({super.key})
    : _size = const Size(220, 180),
      _painter = const _Page1Painter();

  const OnboardingIllustration.page2({super.key})
    : _size = const Size(240, 180),
      _painter = const _Page2Painter();

  const OnboardingIllustration.page3({super.key})
    : _size = const Size(220, 180),
      _painter = const _Page3Painter();

  final Size _size;
  final CustomPainter _painter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: CustomPaint(size: _size, painter: _painter),
      ),
    );
  }
}

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(
  Color color,
  double width, {
  StrokeCap cap = StrokeCap.butt,
  StrokeJoin join = StrokeJoin.miter,
}) => Paint()
  ..style = PaintingStyle.stroke
  ..color = color
  ..strokeWidth = width
  ..strokeCap = cap
  ..strokeJoin = join;

RRect _rect(double x, double y, double w, double h, double rx) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx));

/// Bus on a road with the user's seat tagged.
class _Page1Painter extends CustomPainter {
  const _Page1Painter();

  @override
  void paint(Canvas canvas, Size size) {
    // Road: the wider, fainter stroke is drawn second, on top.
    final road = Path()
      ..moveTo(10, 160)
      ..quadraticBezierTo(110, 140, 210, 155);
    canvas
      ..drawPath(road, _stroke(TroskyColors.whiteA15, 28, cap: StrokeCap.round))
      ..drawPath(
        road,
        _stroke(TroskyColors.whiteA06, 34, cap: StrokeCap.round),
      );

    // Dashed centre line.
    final centre = Path()
      ..moveTo(20, 158)
      ..quadraticBezierTo(110, 140, 200, 154);
    canvas.drawPath(
      dashedPath(centre, const [12, 8]),
      _stroke(TroskyColors.amber, 2, cap: StrokeCap.round),
    );

    // Bus body.
    canvas
      ..drawRRect(_rect(55, 80, 110, 65, 10), _fill(TroskyColors.greenDark))
      ..drawRRect(_rect(62, 87, 96, 45, 6), _fill(TroskyColors.whiteA12));

    // Windows.
    for (final x in const [66.0, 94.0, 122.0]) {
      canvas.drawRRect(_rect(x, 91, 22, 18, 3), _fill(TroskyColors.whiteA85));
    }

    // Seats seen through the windows; the amber one has opacity 0.8.
    final seats = <(double, Color)>[
      (68, TroskyColors.green),
      (79, TroskyColors.green),
      (96, TroskyColors.amber.withValues(alpha: 0.8)),
      (107, TroskyColors.green),
      (124, TroskyColors.green),
      (135, TroskyColors.whiteA30),
    ];
    for (final (x, color) in seats) {
      canvas.drawRRect(_rect(x, 93, 8, 14, 2), _fill(color));
    }

    // Wheels.
    for (final cx in const [82.0, 140.0]) {
      canvas
        ..drawCircle(Offset(cx, 146), 11, _fill(TroskyColors.busWheel))
        ..drawCircle(Offset(cx, 146), 6, _fill(TroskyColors.greenDark));
    }

    // Seat tag. The label is wider than its 36 px pill, as in the design.
    canvas.drawRRect(_rect(90, 72, 36, 20, 10), _fill(TroskyColors.amber));
    paintSvgText(
      canvas,
      'YOUR SEAT',
      TroskyTypography.svgBody9Bold.copyWith(color: TroskyColors.ink),
      const Offset(108, 85),
      anchor: SvgTextAnchor.middle,
    );
    canvas.drawLine(
      const Offset(108, 92),
      const Offset(108, 96),
      _stroke(TroskyColors.amber, 1.5),
    );

    // Stars.
    canvas
      ..drawCircle(const Offset(30, 50), 2, _fill(TroskyColors.whiteA40))
      ..drawCircle(const Offset(185, 40), 1.5, _fill(TroskyColors.whiteA30))
      ..drawCircle(const Offset(200, 70), 1, _fill(TroskyColors.whiteA50))
      ..drawCircle(const Offset(20, 90), 1.5, _fill(TroskyColors.whiteA30));
  }

  @override
  bool shouldRepaint(_Page1Painter oldDelegate) => false;
}

/// Four riders around a coin, each with their share of the fare.
class _Page2Painter extends CustomPainter {
  const _Page2Painter();

  static const _centre = Offset(120, 90);

  // The design's `people` also have x values (30, 90, 150, 210); it never
  // uses them; positions come from the angle below.
  static const _riders = [
    TroskyColors.riderMint,
    TroskyColors.amber,
    TroskyColors.riderSky,
    TroskyColors.riderLavender,
  ];
  static const _fares = [6, 8, 7, 6];

  @override
  void paint(Canvas canvas, Size size) {
    // Fare split rings.
    canvas
      ..drawPath(
        dashedPath(svgCirclePath(_centre, 55), const [4, 4]),
        _stroke(TroskyColors.whiteA08, 1),
      )
      ..drawPath(
        dashedPath(svgCirclePath(_centre, 35), const [4, 4]),
        _stroke(TroskyColors.whiteA12, 1),
      );

    // Central coin.
    canvas.drawCircle(_centre, 20, _fill(TroskyColors.amber));
    paintSvgText(
      canvas,
      '₵',
      TroskyTypography.svgHeading16ExtraBold.copyWith(color: TroskyColors.ink),
      const Offset(120, 95),
      anchor: SvgTextAnchor.middle,
    );

    // Riders: angle = i/4 · 2π − π/2, r = 60, so top, right, bottom, left.
    for (var i = 0; i < _riders.length; i++) {
      final angle = i / 4 * math.pi * 2 - math.pi / 2;
      final p = _centre + Offset(math.cos(angle), math.sin(angle)) * 60;

      // The connector is drawn after the coin, so it crosses it.
      canvas
        ..drawPath(
          dashedPath(
            Path()
              ..moveTo(_centre.dx, _centre.dy)
              ..lineTo(p.dx, p.dy),
            const [3, 3],
          ),
          _stroke(TroskyColors.whiteA10, 1),
        )
        ..drawCircle(p, 18, _fill(_riders[i].withValues(alpha: 0.9)))
        ..drawCircle(p.translate(0, -5), 6, _fill(TroskyColors.whiteA60))
        ..drawOval(
          Rect.fromCenter(center: p.translate(0, 10), width: 20, height: 12),
          _fill(TroskyColors.whiteA40),
        )
        ..drawRRect(
          _rect(p.dx - 12, p.dy + 18, 24, 12, 6),
          _fill(TroskyColors.whiteA20),
        );
      paintSvgText(
        canvas,
        '₵${_fares[i]}',
        TroskyTypography.svgBody7Bold.copyWith(color: TroskyColors.white),
        p.translate(0, 27),
        anchor: SvgTextAnchor.middle,
      );
    }

    // "Price drops" arrow and label, drawn over the top rider's fare chip.
    canvas.drawPath(
      Path()
        ..moveTo(110, 58)
        ..lineTo(120, 70)
        ..lineTo(130, 58),
      _stroke(
        TroskyColors.whiteA50,
        2,
        cap: StrokeCap.round,
        join: StrokeJoin.round,
      ),
    );
    paintSvgText(
      canvas,
      'price drops',
      TroskyTypography.svgBody10SemiBold.copyWith(color: TroskyColors.whiteA70),
      const Offset(120, 50),
      anchor: SvgTextAnchor.middle,
    );
  }

  @override
  bool shouldRepaint(_Page2Painter oldDelegate) => false;
}

/// A calendar week of booked commutes and the route.
class _Page3Painter extends CustomPainter {
  const _Page3Painter();

  static const _dayHeaders = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void paint(Canvas canvas, Size size) {
    // Calendar card. The header band has all four corners rounded.
    canvas
      ..drawRRect(_rect(20, 20, 180, 130, 16), _fill(TroskyColors.whiteA10))
      ..drawRRect(_rect(20, 20, 180, 40, 16), _fill(TroskyColors.whiteA12));
    paintSvgText(
      canvas,
      'July 2026',
      TroskyTypography.svgHeading13Bold.copyWith(color: TroskyColors.white),
      const Offset(110, 46),
      anchor: SvgTextAnchor.middle,
    );

    // Day headers.
    for (var i = 0; i < _dayHeaders.length; i++) {
      paintSvgText(
        canvas,
        _dayHeaders[i],
        TroskyTypography.svgBody8Medium.copyWith(color: TroskyColors.whiteA40),
        Offset(36 + i * 25.0, 82),
        anchor: SvgTextAnchor.middle,
      );
    }

    // Monday to Friday, all ticked. The design's check `[1,2,3,4,5]
    // .includes(i+1)` is always true, so its day numbers (7–11) never show.
    final tick = _stroke(
      TroskyColors.white,
      2,
      cap: StrokeCap.round,
      join: StrokeJoin.round,
    );
    for (var i = 0; i < 5; i++) {
      final x = i * 25.0;
      canvas
        ..drawCircle(Offset(61 + x, 108), 11, _fill(TroskyColors.green))
        ..drawPath(
          Path()
            ..moveTo(55 + x, 108)
            ..lineTo(59 + x, 112)
            ..lineTo(67 + x, 104),
          tick,
        );
    }

    // Route pill.
    canvas
      ..drawRRect(_rect(35, 125, 150, 20, 10), _fill(TroskyColors.whiteA12))
      ..drawCircle(const Offset(48, 135), 4, _fill(TroskyColors.green));
    paintSvgText(
      canvas,
      'Madina → Circle',
      TroskyTypography.svgBody9Regular.copyWith(color: TroskyColors.white),
      const Offset(58, 139),
    );
    paintSvgText(
      canvas,
      '07:15',
      TroskyTypography.svgBody8SemiBold.copyWith(color: TroskyColors.amber),
      const Offset(148, 139),
    );

    // Recurring arrow: a half circle past the card's right edge, and a
    // "head" whose two segments lie on one straight line.
    canvas
      ..drawPath(
        Path()
          ..moveTo(195, 35)
          ..arcToPoint(const Offset(205, 45), radius: const Radius.circular(10))
          ..arcToPoint(
            const Offset(195, 55),
            radius: const Radius.circular(10),
          ),
        _stroke(TroskyColors.amber, 2, cap: StrokeCap.round),
      )
      ..drawPath(
        Path()
          ..moveTo(193, 33)
          ..lineTo(195, 35)
          ..lineTo(197, 37),
        _stroke(
          TroskyColors.amber,
          2,
          cap: StrokeCap.round,
          join: StrokeJoin.round,
        ),
      );
  }

  @override
  bool shouldRepaint(_Page3Painter oldDelegate) => false;
}
