import 'smoothing.dart';

/// A place on Earth, used to look up the magnetic declination for true north.
///
/// The app supplies it (from `geolocator`, a city picker, anything). This
/// package never asks for location permission itself. A rough location is
/// enough: declination changes slowly, a city-level fix is accurate to a
/// fraction of a degree.
class CompassLocation {
  /// Creates a location in degrees, with optional altitude in meters.
  const CompassLocation({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters = 0,
  });

  /// Latitude in degrees, -90 to 90.
  final double latitude;

  /// Longitude in degrees, -180 to 180.
  final double longitude;

  /// Altitude above the WGS84 ellipsoid in meters.
  final double altitudeMeters;

  @override
  bool operator ==(Object other) =>
      other is CompassLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.altitudeMeters == altitudeMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitudeMeters);
}

/// Configuration of a `TrueCompass` stream.
class CompassOptions {
  /// Creates options.
  const CompassOptions({
    this.updateInterval = const Duration(milliseconds: 50),
    this.smoothing = const CompassSmoothing.lowPass(alpha: 0.25),
    this.compensateScreenOrientation = true,
    this.location,
  });

  /// Minimum time between emitted headings. Defaults to 50 ms (20 Hz).
  /// `Duration.zero` emits every sample the sensor produces.
  final Duration updateInterval;

  /// How samples are smoothed before they are emitted.
  final CompassSmoothing smoothing;

  /// Whether headings follow the screen when it rotates to landscape. When
  /// `false` the heading is always that of the top edge of the device in its
  /// natural orientation.
  final bool compensateScreenOrientation;

  /// Where the user is. Needed for `CompassHeading.trueHeading`; can also be
  /// set later with `TrueCompass.setLocation`.
  final CompassLocation? location;

  /// Copy with changes.
  CompassOptions copyWith({
    Duration? updateInterval,
    CompassSmoothing? smoothing,
    bool? compensateScreenOrientation,
    CompassLocation? location,
  }) =>
      CompassOptions(
        updateInterval: updateInterval ?? this.updateInterval,
        smoothing: smoothing ?? this.smoothing,
        compensateScreenOrientation:
            compensateScreenOrientation ?? this.compensateScreenOrientation,
        location: location ?? this.location,
      );
}
