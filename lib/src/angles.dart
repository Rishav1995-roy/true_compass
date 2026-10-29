import 'dart:math' as math;

/// Helpers for working with compass angles in degrees.
///
/// All functions are pure and treat angles as circular, so `359` and `1` are
/// two degrees apart, not 358.
abstract final class Angles {
  /// Normalizes [degrees] into the half-open range `[0, 360)`.
  ///
  /// Negative values (`-10` becomes `350`), values above 360 and negative zero
  /// are all mapped into the range. Non-finite input is returned unchanged so
  /// callers can detect and drop it.
  static double normalize360(double degrees) {
    if (!degrees.isFinite) return degrees;
    var value = degrees % 360.0;
    if (value < 0) value += 360.0;
    // `-1e-20 % 360 + 360` rounds to exactly 360.0.
    if (value >= 360.0) value = 0.0;
    // Collapses -0.0 to 0.0.
    return value + 0.0;
  }

  /// Normalizes [degrees] into `[-180, 180)`.
  static double normalize180(double degrees) {
    final value = normalize360(degrees);
    if (!value.isFinite) return value;
    return value >= 180.0 ? value - 360.0 : value;
  }

  /// The signed shortest rotation that takes [from] to [to], in `[-180, 180)`.
  static double shortestDelta(double from, double to) =>
      normalize180(to - from);

  /// The circular mean of [angles] (optionally [weights]), in `[0, 360)`.
  ///
  /// Returns `null` for an empty list or when the angles cancel out exactly.
  static double? circularMean(List<double> angles, [List<double>? weights]) {
    if (angles.isEmpty) return null;
    var sumSin = 0.0;
    var sumCos = 0.0;
    for (var i = 0; i < angles.length; i++) {
      final weight = weights == null ? 1.0 : weights[i];
      final radians = angles[i] * math.pi / 180.0;
      sumSin += weight * math.sin(radians);
      sumCos += weight * math.cos(radians);
    }
    if (sumSin.abs() < 1e-12 && sumCos.abs() < 1e-12) return null;
    return normalize360(math.atan2(sumSin, sumCos) * 180.0 / math.pi);
  }

  /// Name of the 16-wind compass point for [degrees], e.g. `NNE`.
  static String cardinal16(double degrees) {
    const names = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((normalize360(degrees) + 11.25) ~/ 22.5) % 16;
    return names[index];
  }

  /// Name of the 8-wind compass point for [degrees], e.g. `NE`.
  static String cardinal8(double degrees) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((normalize360(degrees) + 22.5) ~/ 45) % 8;
    return names[index];
  }
}
