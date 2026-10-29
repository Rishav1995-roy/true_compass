import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'angles.dart';
import 'compass_theme.dart';
import 'models.dart';

/// A themeable compass dial.
///
/// The dial rotates so the direction you face is at the top, like a physical
/// compass card, and a fixed needle shows north relative to the phone. Feed
/// it a [heading] value, or a stream of readings with `CompassView.stream`.
///
/// Rotation is animated along the shortest arc, so crossing 359 to 1 degrees
/// never spins the dial the long way round.
class CompassView extends StatefulWidget {
  /// Shows a fixed [heading] in degrees.
  const CompassView({
    super.key,
    required double this.heading,
    this.size,
    this.theme,
    this.trueNorth = true,
    this.animationDuration = const Duration(milliseconds: 120),
    this.targetBearing,
    this.needleBuilder,
    this.centerBuilder,
    this.overlayBuilder,
    this.accuracy,
    this.semanticLabel = 'Compass',
  })  : stream = null,
        initialHeading = null;

  /// Follows a stream of readings. Shows [initialHeading] (default 0) until
  /// the first reading arrives. [trueNorth] picks `trueHeading` when the
  /// reading has one.
  const CompassView.stream({
    super.key,
    required Stream<CompassHeading> this.stream,
    this.initialHeading,
    this.size,
    this.theme,
    this.trueNorth = true,
    this.animationDuration = const Duration(milliseconds: 120),
    this.targetBearing,
    this.needleBuilder,
    this.centerBuilder,
    this.overlayBuilder,
    this.semanticLabel = 'Compass',
  })  : heading = null,
        accuracy = null;

  /// Fixed heading in degrees (the plain constructor).
  final double? heading;

  /// Stream of readings (the `stream` constructor).
  final Stream<CompassHeading>? stream;

  /// Heading shown before the first stream event.
  final double? initialHeading;

  /// Side length. Defaults to the available space (shortest side, 280 if
  /// unbounded).
  final double? size;

  /// Visual theme. Defaults to light or dark by the ambient brightness.
  final CompassTheme? theme;

  /// Whether to use true north (needs a location) or magnetic north.
  final bool trueNorth;

  /// Duration of the rotation animation. `Duration.zero` disables it.
  final Duration animationDuration;

  /// Optional bearing in degrees from north to mark on the dial, for example
  /// the Qibla direction or a destination.
  final double? targetBearing;

  /// Replaces the default needle. Receives the dial radius and theme; it is
  /// drawn pointing to north, which the view rotates for you.
  final Widget Function(
      BuildContext context, double radius, CompassTheme theme)? needleBuilder;

  /// Content in the middle of the dial, for example the degree readout.
  /// Receives the current heading in degrees.
  final Widget Function(BuildContext context, double heading)? centerBuilder;

  /// Content drawn above the dial and not rotated, such as a fixed lubber
  /// line. Receives the dial size.
  final Widget Function(BuildContext context, double size)? overlayBuilder;

  /// Accuracy used for the semantics label with the plain constructor.
  final CompassAccuracy? accuracy;

  /// Accessibility label; the heading is appended.
  final String semanticLabel;

  @override
  State<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends State<CompassView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _from;
  late double _to;
  // Unwrapped angle so interpolation follows the shortest arc.
  late double _unwrapped;
  double _displayed = 0;
  CompassAccuracy? _accuracy;
  Stream<CompassHeading>? _subscribedTo;
  dynamic _subscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(() => setState(() {
            _displayed = Angles.normalize360(
              _from + (_to - _from) * _controller.value,
            );
          }));
    final start = widget.heading ?? widget.initialHeading ?? 0;
    _unwrapped = _from = _to = start;
    _displayed = Angles.normalize360(start);
    _accuracy = widget.accuracy;
    _attach();
  }

  void _attach() {
    final stream = widget.stream;
    if (identical(stream, _subscribedTo)) return;
    _subscription?.cancel();
    _subscribedTo = stream;
    _subscription = stream?.listen((reading) {
      _accuracy = reading.accuracy;
      _setTarget(reading.headingFor(trueNorth: widget.trueNorth));
    });
  }

  void _setTarget(double degrees) {
    if (!degrees.isFinite) return;
    final delta = Angles.shortestDelta(_unwrapped, degrees);
    _from = _unwrapped;
    _unwrapped = _unwrapped + delta;
    _to = _unwrapped;
    if (widget.animationDuration == Duration.zero) {
      setState(() => _displayed = Angles.normalize360(degrees));
      return;
    }
    _controller.duration = widget.animationDuration;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(CompassView old) {
    super.didUpdateWidget(old);
    _attach();
    final heading = widget.heading;
    if (heading != null && heading != old.heading) _setTarget(heading);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final theme = widget.theme ??
        (brightness == Brightness.dark
            ? const CompassTheme.dark()
            : const CompassTheme());
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = widget.size ??
            (constraints.hasBoundedWidth || constraints.hasBoundedHeight
                ? math.min(constraints.maxWidth, constraints.maxHeight)
                : 280.0);
        final dialSize = side.isFinite ? side : 280.0;
        final radius = dialSize / 2;
        final rad = _displayed * math.pi / 180;
        return Semantics(
          label: '${widget.semanticLabel}, ${_displayed.round()} degrees '
              '${Angles.cardinal8(_displayed)}'
              '${_accuracy == null ? '' : ', accuracy ${_accuracy!.name}'}',
          child: SizedBox.square(
            dimension: dialSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -rad,
                  child: CustomPaint(
                    size: Size.square(dialSize),
                    painter: _DialPainter(
                      theme: theme,
                      textDirection: Directionality.of(context),
                      textScale: MediaQuery.textScalerOf(context),
                      baseStyle: DefaultTextStyle.of(context).style,
                      targetBearing: widget.targetBearing,
                    ),
                  ),
                ),
                if (theme.showNeedle || widget.needleBuilder != null)
                  // The needle points at north; the card has rotated by
                  // -heading, so north sits at -heading on screen.
                  Transform.rotate(
                    angle: -rad,
                    child: widget.needleBuilder?.call(context, radius, theme) ??
                        CustomPaint(
                          size: Size.square(dialSize),
                          painter: _NeedlePainter(theme),
                        ),
                  ),
                if (widget.centerBuilder != null)
                  widget.centerBuilder!(context, _displayed),
                if (widget.overlayBuilder != null)
                  widget.overlayBuilder!(context, dialSize),
                // Fixed lubber marker at the top: the direction you face.
                Positioned(
                  top: 0,
                  child: CustomPaint(
                    size: Size(radius * 0.12, radius * 0.16),
                    painter: _LubberPainter(theme.hubColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.theme,
    required this.textDirection,
    required this.textScale,
    required this.baseStyle,
    required this.targetBearing,
  });

  final CompassTheme theme;
  final TextDirection textDirection;
  final TextScaler textScale;
  final TextStyle baseStyle;
  final double? targetBearing;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - theme.borderWidth / 2 - 1;
    final face = Paint()
      ..shader = (theme.dialGradientEdge == null
          ? null
          : RadialGradient(colors: [theme.dialColor, theme.dialGradientEdge!])
              .createShader(Rect.fromCircle(center: c, radius: r)))
      ..color = theme.dialColor;
    if (theme.showShadow) {
      canvas.drawShadow(
        Path()..addOval(Rect.fromCircle(center: c, radius: r)),
        const Color(0xFF000000),
        6,
        false,
      );
    }
    canvas.drawCircle(c, r, face);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme.borderWidth
        ..color = theme.borderColor,
    );

    // Angles are measured clockwise from the top of the (unrotated) card.
    void ray(double degrees, double from, double to, Paint paint) {
      final a = degrees * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * from, c + dir * to, paint);
    }

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = theme.tickColor
      ..strokeWidth = 1.2;
    final majorPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = theme.majorTickColor
      ..strokeWidth = 2.2;
    final count = math.max(theme.tickCount, 4);
    for (var i = 0; i < count; i++) {
      final deg = 360.0 * i / count;
      final major = theme.majorTickEvery > 0 && i % theme.majorTickEvery == 0;
      ray(deg, r * (major ? 0.86 : 0.91), r * 0.97,
          major ? majorPaint : tickPaint);
    }

    void label(String text, double degrees, double radius, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScale,
      )..layout();
      final a = degrees * math.pi / 180;
      final p = c + Offset(math.sin(a), -math.cos(a)) * radius;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      // Keep the glyphs radially oriented, like a printed compass card.
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final base = baseStyle.copyWith(
      color: theme.majorTickColor,
      fontSize: r * 0.15,
      fontWeight: FontWeight.w700,
    );
    if (theme.showCardinals) {
      label(
        'N',
        0,
        r * 0.70,
        theme.northStyle ??
            base.copyWith(color: theme.northColor, fontSize: r * 0.19),
      );
      for (final entry in const {'E': 90.0, 'S': 180.0, 'W': 270.0}.entries) {
        label(entry.key, entry.value, r * 0.70, theme.cardinalStyle ?? base);
      }
    }
    if (theme.showIntercardinals) {
      final small = (theme.cardinalStyle ?? base).copyWith(
        fontSize: r * 0.09,
        fontWeight: FontWeight.w500,
        color: theme.tickColor,
      );
      for (final entry in const {
        'NE': 45.0,
        'SE': 135.0,
        'SW': 225.0,
        'NW': 315.0
      }.entries) {
        label(entry.key, entry.value, r * 0.72, small);
      }
    }
    if (theme.showDegreeLabels && theme.degreeLabelEvery > 0) {
      final style = theme.degreeLabelStyle ??
          baseStyle.copyWith(color: theme.tickColor, fontSize: r * 0.07);
      for (var d = 0; d < 360; d += theme.degreeLabelEvery) {
        if (theme.showCardinals && d % 90 == 0) continue;
        label('$d', d.toDouble(), r * 0.78, style);
      }
    }
    // North marker triangle on the ring.
    final n = Path()
      ..moveTo(c.dx, c.dy - r * 0.99)
      ..lineTo(c.dx - r * 0.04, c.dy - r * 0.90)
      ..lineTo(c.dx + r * 0.04, c.dy - r * 0.90)
      ..close();
    canvas.drawPath(n, Paint()..color = theme.northColor);

    final target = targetBearing;
    if (target != null && target.isFinite) {
      final a = target * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        c + dir * r * 0.30,
        c + dir * r * 0.84,
        Paint()
          ..color = theme.targetColor
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
          c + dir * r * 0.88, r * 0.045, Paint()..color = theme.targetColor);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.theme != theme ||
      old.targetBearing != targetBearing ||
      old.textScale != textScale ||
      old.baseStyle != baseStyle ||
      old.textDirection != textDirection;
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter(this.theme);

  final CompassTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final north = Path()
      ..moveTo(c.dx, c.dy - r * 0.50)
      ..lineTo(c.dx - r * 0.07, c.dy)
      ..lineTo(c.dx + r * 0.07, c.dy)
      ..close();
    final south = Path()
      ..moveTo(c.dx, c.dy + r * 0.34)
      ..lineTo(c.dx - r * 0.07, c.dy)
      ..lineTo(c.dx + r * 0.07, c.dy)
      ..close();
    canvas.drawPath(south, Paint()..color = theme.needleTailColor);
    canvas.drawPath(north, Paint()..color = theme.needleColor);
    canvas.drawCircle(c, r * 0.06, Paint()..color = theme.hubColor);
    canvas.drawCircle(c, r * 0.025, Paint()..color = theme.dialColor);
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.theme != theme;
}

class _LubberPainter extends CustomPainter {
  _LubberPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LubberPainter old) => old.color != color;
}
