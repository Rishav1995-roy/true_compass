import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

void main() {
  group('Angles', () {
    test('normalize360 maps negatives, overflow and negative zero', () {
      expect(Angles.normalize360(-10), 350);
      expect(Angles.normalize360(370), 10);
      expect(Angles.normalize360(360), 0);
      expect(Angles.normalize360(-720), 0);
      expect(Angles.normalize360(-0.0).isNegative, isFalse);
      expect(Angles.normalize360(-1e-20), 0);
      expect(Angles.normalize360(359.9999), closeTo(359.9999, 1e-9));
    });

    test('normalize360 leaves NaN for the caller to drop', () {
      expect(Angles.normalize360(double.nan).isNaN, isTrue);
    });

    test('shortestDelta crosses north', () {
      expect(Angles.shortestDelta(359, 1), 2);
      expect(Angles.shortestDelta(1, 359), -2);
      expect(Angles.shortestDelta(0, 180).abs(), 180);
    });

    test('circularMean of 359 and 1 is 0, not 180', () {
      expect(Angles.circularMean([359, 1])!, closeTo(0, 1e-9));
      expect(Angles.circularMean([350, 10, 0])!, closeTo(0, 1e-9));
      expect(Angles.circularMean([0, 180]), isNull);
      expect(Angles.circularMean([]), isNull);
    });

    test('cardinal names', () {
      expect(Angles.cardinal8(0), 'N');
      expect(Angles.cardinal8(359), 'N');
      expect(Angles.cardinal8(46), 'NE');
      expect(Angles.cardinal16(22.5), 'NNE');
      expect(Angles.cardinal16(-1), 'N');
    });
  });

  group('smoothing', () {
    double settle(CompassSmoothing s, List<double> input) {
      final f = s.createSmoother();
      var last = 0.0;
      for (final v in input) {
        last = f.add(v);
      }
      return last;
    }

    final jitter = [for (var i = 0; i < 40; i++) i.isEven ? 359.0 : 1.0];

    test('low-pass settles near 0 on a 359/1 jitter (no jump to 180)', () {
      final f = const CompassSmoothing.lowPass(alpha: 0.3).createSmoother();
      for (final v in jitter) {
        final out = f.add(v);
        expect(Angles.shortestDelta(out, 0).abs(), lessThan(3));
      }
    });

    test('circular average settles near 0 on a 359/1 jitter', () {
      final out =
          settle(const CompassSmoothing.circularAverage(window: 6), jitter);
      expect(Angles.shortestDelta(out, 0).abs(), lessThan(1.5));
    });

    test('low-pass converges to a steady heading', () {
      final out = settle(
        const CompassSmoothing.lowPass(alpha: 0.2),
        List.filled(60, 123.0),
      );
      expect(out, closeTo(123, 0.01));
    });

    test('low-pass output is always in [0, 360)', () {
      final f = const CompassSmoothing.lowPass(alpha: 0.5).createSmoother();
      for (var i = 0; i < 200; i++) {
        final out = f.add(i * 17.0 - 1000);
        expect(out, inInclusiveRange(0, 359.999999));
      }
    });

    test('none passes through (normalized)', () {
      final f = const CompassSmoothing.none().createSmoother();
      expect(f.add(-5), 355);
    });

    test('reset forgets history', () {
      final f = const CompassSmoothing.lowPass(alpha: 0.1).createSmoother();
      f.add(10);
      f.reset();
      expect(f.add(200), 200);
    });
  });
}
