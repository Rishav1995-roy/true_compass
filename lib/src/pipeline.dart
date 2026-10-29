import 'angles.dart';
import 'magnetic_declination.dart';
import 'models.dart';
import 'options.dart';
import 'orientation_math.dart';
import 'smoothing.dart';

/// Turns raw platform events into [CompassHeading]s: orientation math,
/// accuracy tracking, smoothing and true-north correction. Pure Dart.
class HeadingPipeline {
  /// Creates a pipeline for [options]. [clock] is injectable for tests.
  HeadingPipeline(this.options, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _smoother = options.smoothing.createSmoother(),
        _location = options.location;

  /// The options the pipeline was created with.
  final CompassOptions options;

  final DateTime Function() _clock;
  final HeadingSmoother _smoother;
  CompassLocation? _location;
  double? _declination;
  DateTime? _declinationAt;

  /// The latest known accuracy.
  CompassAccuracy accuracy = CompassAccuracy.unknown;
  double? _errorDegrees;

  /// Sets or clears the location used for true north.
  void setLocation(CompassLocation? location) {
    if (location == _location) return;
    _location = location;
    _declination = null;
  }

  /// The declination for the current location, recomputed once a day.
  double? get declination {
    final location = _location;
    if (location == null) return null;
    final now = _clock();
    final computedAt = _declinationAt;
    if (_declination == null ||
        computedAt == null ||
        now.difference(computedAt).inHours.abs() >= 24) {
      _declination = MagneticDeclination.at(
        latitude: location.latitude,
        longitude: location.longitude,
        altitudeMeters: location.altitudeMeters,
        date: now,
      );
      _declinationAt = now;
    }
    return _declination;
  }

  /// Handles an accuracy or calibration event. Returns the new accuracy when
  /// it changed, otherwise `null`.
  CompassAccuracy? processAccuracyEvent(Map<String, Object?> event) {
    final CompassAccuracy next;
    switch (event['kind']) {
      case 'calibration':
        next = CompassAccuracy.unreliable;
      case 'accuracy':
        final status = event['status'];
        if (status is num) {
          next = CompassAccuracy.fromAndroidStatus(status.toInt());
        } else {
          final error = _asDouble(event['errorDegrees']);
          _errorDegrees = error;
          next = CompassAccuracy.fromErrorDegrees(error);
        }
      default:
        return null;
    }
    if (next == accuracy) return null;
    accuracy = next;
    return next;
  }

  /// Converts a `matrix`, `heading` or `euler` event to a heading, or `null`
  /// when the sample is unusable (NaN, ambiguous orientation, a browser that
  /// has no north reference).
  CompassHeading? processSample(Map<String, Object?> event) {
    final rotation = options.compensateScreenOrientation
        ? (_asDouble(event['screenRotation']) ?? 0).round()
        : 0;
    double? magnetic;
    switch (event['kind']) {
      case 'matrix':
        final raw = event['matrix'];
        if (raw is! List) return null;
        final matrix = <double>[
          for (final v in raw) (v as num).toDouble(),
        ];
        magnetic = OrientationMath.headingFromRotationMatrix(
          matrix,
          screenRotation: rotation,
        );
      case 'euler':
        if (event['absolute'] != true) return null;
        final alpha = _asDouble(event['alpha']);
        final beta = _asDouble(event['beta']);
        final gamma = _asDouble(event['gamma']);
        if (alpha == null || beta == null || gamma == null) return null;
        magnetic = OrientationMath.headingFromEuler(
          alpha,
          beta,
          gamma,
          screenRotation: rotation,
        );
      case 'heading':
        final heading = _asDouble(event['heading']);
        if (heading == null || !heading.isFinite) return null;
        magnetic = event['compensated'] == true
            ? Angles.normalize360(heading)
            : OrientationMath.compensateScreenRotation(heading, rotation);
      default:
        return null;
    }
    if (magnetic == null || !magnetic.isFinite) return null;
    final error = _asDouble(event['errorDegrees']);
    if (error != null) {
      _errorDegrees = error;
      // Platforms that report an error but no coarse status.
      if (event['kind'] != 'matrix') {
        accuracy = CompassAccuracy.fromErrorDegrees(error);
      }
    }
    final smoothed = _smoother.add(magnetic);
    final declination = this.declination;
    return CompassHeading(
      magneticHeading: smoothed,
      declination: declination,
      trueHeading: declination == null ? null : smoothed + declination,
      accuracy: accuracy,
      errorDegrees: _errorDegrees,
      timestamp: _clock(),
    );
  }

  static double? _asDouble(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;
}
