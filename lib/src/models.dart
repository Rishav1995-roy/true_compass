import 'angles.dart';

/// How trustworthy the magnetometer currently is.
///
/// Android reports four levels; iOS reports a heading error in degrees which
/// is mapped onto the same scale by [CompassAccuracy.fromErrorDegrees].
enum CompassAccuracy {
  /// The platform does not report accuracy (most browsers).
  unknown,

  /// Readings should not be trusted; the user must calibrate the compass.
  unreliable,

  /// Large error (roughly more than 25 degrees); calibration recommended.
  low,

  /// Moderate error (roughly 10 to 25 degrees).
  medium,

  /// Good (roughly under 10 degrees).
  high;

  /// Maps Android's `SensorManager.SENSOR_STATUS_*` constant (0..3).
  static CompassAccuracy fromAndroidStatus(int? status) => switch (status) {
        0 => CompassAccuracy.unreliable,
        1 => CompassAccuracy.low,
        2 => CompassAccuracy.medium,
        3 => CompassAccuracy.high,
        _ => CompassAccuracy.unknown,
      };

  /// Maps an estimated heading error in degrees (negative means invalid).
  static CompassAccuracy fromErrorDegrees(double? error) {
    if (error == null || error.isNaN) return CompassAccuracy.unknown;
    if (error < 0) return CompassAccuracy.unreliable;
    if (error <= 10) return CompassAccuracy.high;
    if (error <= 25) return CompassAccuracy.medium;
    if (error <= 45) return CompassAccuracy.low;
    return CompassAccuracy.unreliable;
  }

  /// Whether the user should be asked to wave the phone in a figure of eight.
  bool get needsCalibration =>
      this == CompassAccuracy.unreliable || this == CompassAccuracy.low;
}

/// Whether and how the compass can be used on this device.
enum CompassAvailability {
  /// Sensors are present and permitted.
  available,

  /// The device has no usable magnetometer / orientation sensor.
  noSensor,

  /// The sensor exists but the user must grant permission first (iOS Safari
  /// on the web). Call `TrueCompass.requestPermission` from a tap handler.
  permissionRequired,

  /// The user declined the sensor permission.
  permissionDenied,

  /// The web page is not served over HTTPS, so browsers hide the sensors.
  insecureContext,

  /// The current platform has no implementation (desktop).
  unsupported,
}

/// One compass reading.
class CompassHeading {
  /// Creates a heading sample. Angles are normalized to `[0, 360)`.
  CompassHeading({
    required double magneticHeading,
    double? trueHeading,
    this.declination,
    this.accuracy = CompassAccuracy.unknown,
    this.errorDegrees,
    DateTime? timestamp,
  })  : magneticHeading = Angles.normalize360(magneticHeading),
        trueHeading =
            trueHeading == null ? null : Angles.normalize360(trueHeading),
        timestamp = timestamp ?? DateTime.now();

  /// Heading relative to magnetic north in degrees, `[0, 360)`.
  final double magneticHeading;

  /// Heading relative to true north in degrees, `[0, 360)`, or `null` when no
  /// location was supplied so the declination is unknown.
  final double? trueHeading;

  /// Magnetic declination used to compute [trueHeading], in degrees.
  final double? declination;

  /// Current sensor accuracy.
  final CompassAccuracy accuracy;

  /// Estimated heading error in degrees when the platform reports it.
  final double? errorDegrees;

  /// When the sample was produced.
  final DateTime timestamp;

  /// The best heading to show: [trueHeading] when known, else
  /// [magneticHeading].
  double get bestHeading => trueHeading ?? magneticHeading;

  /// Whether [accuracy] says the compass should be calibrated.
  bool get needsCalibration => accuracy.needsCalibration;

  /// Returns the heading for the given north reference.
  double headingFor({required bool trueNorth}) =>
      trueNorth ? bestHeading : magneticHeading;

  @override
  String toString() =>
      'CompassHeading(magnetic: ${magneticHeading.toStringAsFixed(1)}, '
      'true: ${trueHeading?.toStringAsFixed(1)}, accuracy: ${accuracy.name})';
}
