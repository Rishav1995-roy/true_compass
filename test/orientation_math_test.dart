import 'dart:math' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

void main() {
  // Row-major device-to-world matrices (x east, y north, z up).
  const flatNorth = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
  const flatEast = <double>[0, 1, 0, -1, 0, 0, 0, 0, 1];
  // Held upright in portrait with the back camera facing north.
  const uprightNorth = <double>[1, 0, 0, 0, 0, -1, 0, 1, 0];
  // Flat, top edge pointing west (landscape, device turned counter-clockwise),
  // user facing north.
  const landscapeFacingNorth = <double>[0, -1, 0, 1, 0, 0, 0, 0, 1];

  group('headingFromRotationMatrix', () {
    test('flat, top edge north / east', () {
      expect(OrientationMath.headingFromRotationMatrix(flatNorth),
          closeTo(0, 1e-9));
      expect(OrientationMath.headingFromRotationMatrix(flatEast),
          closeTo(90, 1e-9));
    });

    test('upright uses the back camera direction', () {
      expect(
        OrientationMath.headingFromRotationMatrix(uprightNorth),
        closeTo(0, 1e-9),
      );
    });

    test('screen rotation: landscape keeps pointing where the user faces', () {
      expect(
        OrientationMath.headingFromRotationMatrix(landscapeFacingNorth),
        closeTo(270, 1e-9),
        reason: 'without compensation the top edge points west',
      );
      expect(
        OrientationMath.headingFromRotationMatrix(
          landscapeFacingNorth,
          screenRotation: 90,
        ),
        closeTo(0, 1e-9),
      );
    });

    test('180 and 270 rotations', () {
      expect(
        OrientationMath.headingFromRotationMatrix(flatNorth,
            screenRotation: 180),
        closeTo(180, 1e-9),
      );
      expect(
        OrientationMath.headingFromRotationMatrix(flatNorth,
            screenRotation: 270),
        closeTo(270, 1e-9),
      );
    });

    test('tilting from flat to upright does not change the heading', () {
      // Pitch the top edge up by t degrees while facing north.
      for (var t = 0; t <= 80; t += 10) {
        final r = t * 3.141592653589793 / 180;
        final c = _cos(r), s = _sin(r);
        // x east; y = (0, c, s); z = x cross y = (0, -s, c)
        final m = <double>[1, 0, 0, 0, c, -s, 0, s, c];
        expect(
          OrientationMath.headingFromRotationMatrix(m),
          closeTo(0, 1e-9),
          reason: 'tilt $t',
        );
      }
    });

    test('returns null for NaN, wrong length and screen-down vertical', () {
      expect(
        OrientationMath.headingFromRotationMatrix(
            [...flatNorth]..[0] = double.nan),
        isNull,
      );
      expect(OrientationMath.headingFromRotationMatrix([1, 2]), isNull);
      // Vertical, screen facing the ground: y up, z down => ambiguous.
      expect(
        OrientationMath.headingFromRotationMatrix(
          const [1, 0, 0, 0, 0, 0, 0, 1, 0],
        ),
        isNull,
      );
    });

    test('result is never negative', () {
      for (var a = -720.0; a <= 720; a += 7.3) {
        final h = OrientationMath.headingFromEuler(a, 3, -2)!;
        expect(h, inInclusiveRange(0, 359.9999999));
      }
    });
  });

  group('web Euler angles', () {
    test('alpha counter-clockwise from north gives clockwise heading', () {
      expect(OrientationMath.headingFromEuler(0, 0, 0), closeTo(0, 1e-9));
      expect(OrientationMath.headingFromEuler(90, 0, 0), closeTo(270, 1e-9));
      expect(OrientationMath.headingFromEuler(270, 0, 0), closeTo(90, 1e-9));
    });

    test('webkit heading follows the screen rotation', () {
      expect(OrientationMath.compensateScreenRotation(270, 90), 0);
      expect(OrientationMath.compensateScreenRotation(10, 270), 280);
    });
  });
}

double _cos(double r) => m.cos(r);
double _sin(double r) => m.sin(r);
