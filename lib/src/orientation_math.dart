import 'dart:math' as math;

import 'angles.dart';

/// Pure functions that turn raw sensor data into a compass heading.
///
/// The same code serves Android (rotation matrix), web (Euler angles) and
/// the screen-rotation correction for every platform, so it is unit tested
/// without a device.
abstract final class OrientationMath {
  /// Heading in degrees (clockwise from magnetic north, `[0, 360)`) of the
  /// direction the user is facing, from a 3x3 row-major rotation matrix that
  /// maps device axes to world axes (x east, y north, z up). This is the
  /// layout of Android's `SensorManager.getRotationMatrixFromVector`.
  ///
  /// [screenRotation] is the display rotation in degrees (0, 90, 180, 270,
  /// counter-clockwise device rotation as in `screen.orientation.angle`); the
  /// result is the direction of the top of the screen.
  ///
  /// When the phone is flat the top edge is used, when it is held upright the
  /// back camera direction is used, and in between both are blended. Returns
  /// `null` when the direction is ambiguous (phone vertical and screen facing
  /// the ground) or the matrix is invalid.
  static double? headingFromRotationMatrix(
    List<double> r, {
    int screenRotation = 0,
  }) {
    if (r.length != 9 || r.any((v) => !v.isFinite)) return null;
    // World coordinates of the screen-up axis (device frame, per rotation).
    final (ux, uy) = switch (Angles.normalize360(screenRotation.toDouble())) {
      >= 45 && < 135 => (1.0, 0.0),
      >= 135 && < 225 => (0.0, -1.0),
      >= 225 && < 315 => (-1.0, 0.0),
      _ => (0.0, 1.0),
    };
    final upEast = r[0] * ux + r[1] * uy;
    final upNorth = r[3] * ux + r[4] * uy;
    // Back camera axis is -z in the device frame.
    final backEast = -r[2];
    final backNorth = -r[5];
    final east = upEast + backEast;
    final north = upNorth + backNorth;
    if (math.sqrt(east * east + north * north) < 0.05) return null;
    return Angles.normalize360(math.atan2(east, north) * 180.0 / math.pi);
  }

  /// Builds the row-major device-to-world rotation matrix from the W3C
  /// `DeviceOrientationEvent` angles ([alpha], [beta], [gamma] in degrees).
  static List<double> rotationMatrixFromEuler(
    double alpha,
    double beta,
    double gamma,
  ) {
    final a = alpha * math.pi / 180.0;
    final b = beta * math.pi / 180.0;
    final g = gamma * math.pi / 180.0;
    final cA = math.cos(a), sA = math.sin(a);
    final cB = math.cos(b), sB = math.sin(b);
    final cG = math.cos(g), sG = math.sin(g);
    return [
      cG * cA - sA * sB * sG, -cB * sA, cG * sA * sB + cA * sG, //
      cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB, //
      -cB * sG, sB, cB * cG,
    ];
  }

  /// Heading from W3C Euler angles; see [headingFromRotationMatrix].
  static double? headingFromEuler(
    double alpha,
    double beta,
    double gamma, {
    int screenRotation = 0,
  }) =>
      headingFromRotationMatrix(
        rotationMatrixFromEuler(alpha, beta, gamma),
        screenRotation: screenRotation,
      );

  /// Applies the screen rotation to a heading of the device's top edge, such
  /// as Safari's `webkitCompassHeading`, which ignores screen rotation.
  static double compensateScreenRotation(
    double topEdgeHeading,
    int screenRotation,
  ) =>
      Angles.normalize360(topEdgeHeading + screenRotation);
}
