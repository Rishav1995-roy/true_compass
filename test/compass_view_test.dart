import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Center(child: child)),
    );

double dialAngle(WidgetTester tester) {
  final t = tester.widgetList<Transform>(find.byType(Transform)).firstWhere(
        (t) => t.child is CustomPaint,
      );
  return math.atan2(t.transform.entry(1, 0), t.transform.entry(0, 0));
}

void main() {
  testWidgets('renders and exposes a semantics label', (tester) async {
    await tester.pumpWidget(host(const CompassView(heading: 90, size: 240)));
    expect(find.byType(CompassView), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Compass, 90 degrees E')),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(CompassView)), const Size(240, 240));
  });

  testWidgets('dial rotates by -heading', (tester) async {
    await tester.pumpWidget(host(const CompassView(heading: 90, size: 200)));
    expect(dialAngle(tester), closeTo(-math.pi / 2, 1e-6));
  });

  testWidgets('359 -> 1 animates the short way (no spin through 180)',
      (tester) async {
    final heading = ValueNotifier<double>(359);
    await tester.pumpWidget(
      host(
        ValueListenableBuilder<double>(
          valueListenable: heading,
          builder: (_, h, __) => CompassView(
            heading: h,
            size: 200,
            animationDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    heading.value = 1;
    final seen = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      // Displayed heading = -dial angle in degrees, wrapped.
      seen.add(Angles.normalize360(-dialAngle(tester) * 180 / math.pi));
    }
    for (final h in seen) {
      expect(Angles.shortestDelta(h, 0).abs(), lessThanOrEqualTo(2.0001),
          reason: '$h');
    }
  });

  testWidgets('follows a stream and respects trueNorth', (tester) async {
    final controller = StreamController<CompassHeading>.broadcast();
    await tester.pumpWidget(
      host(
        CompassView.stream(
          stream: controller.stream,
          size: 200,
          animationDuration: Duration.zero,
        ),
      ),
    );
    controller.add(CompassHeading(magneticHeading: 10, trueHeading: 25));
    await tester.idle();
    await tester.pump();
    expect(dialAngle(tester), closeTo(-25 * math.pi / 180, 1e-6));

    await tester.pumpWidget(
      host(
        CompassView.stream(
          stream: controller.stream,
          size: 200,
          trueNorth: false,
          animationDuration: Duration.zero,
        ),
      ),
    );
    controller.add(CompassHeading(magneticHeading: 10, trueHeading: 25));
    await tester.idle();
    await tester.pump();
    expect(dialAngle(tester), closeTo(-10 * math.pi / 180, 1e-6));
    await controller.close();
  });

  testWidgets('theme, builders, target and dark mode build', (tester) async {
    await tester.pumpWidget(
      host(
        CompassView(
          heading: 45,
          theme: const CompassTheme(showDegreeLabels: true, showShadow: false),
          targetBearing: 120,
          centerBuilder: (_, h) => Text('${h.round()}'),
          overlayBuilder: (_, size) => const SizedBox(key: Key('overlay')),
          needleBuilder: (_, r, t) =>
              SizedBox(key: const Key('needle'), width: r),
        ),
        b: Brightness.dark,
      ),
    );
    expect(find.text('45'), findsOneWidget);
    expect(find.byKey(const Key('overlay')), findsOneWidget);
    expect(find.byKey(const Key('needle')), findsOneWidget);
  });

  testWidgets('fromColorScheme and copyWith', (tester) async {
    final theme = CompassTheme.fromColorScheme(const ColorScheme.light());
    final copy = theme.copyWith(showNeedle: false, tickCount: 36);
    await tester.pumpWidget(host(CompassView(heading: 0, theme: copy)));
    expect(copy.tickCount, 36);
  });
}
