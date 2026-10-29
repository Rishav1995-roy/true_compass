import 'dart:async';
import 'dart:math' as math;

import 'package:true_compass/true_compass.dart';

/// A synthetic heading stream: a slow clockwise sweep with sensor noise that
/// crosses north repeatedly. Used when the device has no magnetometer, and to
/// render the README demo. It is clearly simulated, never real sensor data.
Stream<CompassHeading> simulatedHeadings({
  Duration interval = const Duration(milliseconds: 50),
  double degreesPerSecond = 40,
  double noiseDegrees = 1.5,
  double declination = 0,
  CompassAccuracy accuracy = CompassAccuracy.high,
  double start = 300,
}) async* {
  final random = math.Random(7);
  var t = 0.0;
  while (true) {
    await Future<void>.delayed(interval);
    t += interval.inMicroseconds / 1e6;
    final base = start + degreesPerSecond * t;
    final noisy = base + (random.nextDouble() - 0.5) * 2 * noiseDegrees;
    yield CompassHeading(
      magneticHeading: noisy,
      trueHeading: noisy + declination,
      declination: declination,
      accuracy: accuracy,
    );
  }
}
