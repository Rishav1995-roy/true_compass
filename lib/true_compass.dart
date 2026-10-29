/// Compass heading for Flutter with magnetic and true north, calibration
/// events, smoothing and a themeable dial.
library;

export 'src/angles.dart' show Angles;
export 'src/compass_theme.dart' show CompassTheme;
export 'src/compass_view.dart' show CompassView;
export 'src/magnetic_declination.dart' show MagneticDeclination, MagneticField;
export 'src/models.dart'
    show CompassAccuracy, CompassAvailability, CompassHeading;
export 'src/options.dart' show CompassLocation, CompassOptions;
export 'src/orientation_math.dart' show OrientationMath;
export 'src/smoothing.dart'
    show
        CircularAverageSmoothing,
        CompassSmoothing,
        HeadingSmoother,
        LowPassSmoothing,
        NoSmoothing;
export 'src/true_compass_base.dart' show TrueCompass;
export 'true_compass_platform_interface.dart'
    show RawSensorConfig, TrueCompassPlatform;
