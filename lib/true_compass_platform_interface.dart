import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models.dart';
import 'true_compass_method_channel.dart';

/// Sensor settings handed to the native side.
class RawSensorConfig {
  /// Creates a config.
  const RawSensorConfig({
    required this.interval,
    required this.compensateScreenOrientation,
  });

  /// Requested sample interval.
  final Duration interval;

  /// Whether the native side should follow screen rotation (iOS).
  final bool compensateScreenOrientation;
}

/// The interface platform implementations must extend.
///
/// Raw events are maps with a `kind` key:
///
/// * `matrix`: `matrix` (9 doubles, row-major device-to-world), `screenRotation`
///   (degrees), optional `errorDegrees`. Android.
/// * `heading`: `heading` (magnetic degrees), `compensated` (bool, true when
///   the value already follows the screen), `screenRotation`, optional
///   `errorDegrees`. iOS and iOS Safari.
/// * `euler`: `alpha`, `beta`, `gamma`, `absolute` (bool), `screenRotation`.
///   Web.
/// * `accuracy`: `status` (Android 0..3) or `errorDegrees`.
/// * `calibration`: the OS asks to show the calibration prompt (iOS).
abstract class TrueCompassPlatform extends PlatformInterface {
  /// Constructs a platform.
  TrueCompassPlatform() : super(token: _token);

  static final Object _token = Object();

  static TrueCompassPlatform _instance = MethodChannelTrueCompass();

  /// The current implementation. Defaults to [MethodChannelTrueCompass].
  static TrueCompassPlatform get instance => _instance;

  /// Replaces the implementation (platform packages and tests).
  static set instance(TrueCompassPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Whether the compass can be used.
  Future<CompassAvailability> checkAvailability() {
    throw UnimplementedError('checkAvailability() has not been implemented.');
  }

  /// Asks the user for sensor permission where the platform needs it.
  Future<CompassAvailability> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Raw sensor events. The sensor runs only while the stream is listened to.
  Stream<Map<String, Object?>> rawEvents(RawSensorConfig config) {
    throw UnimplementedError('rawEvents() has not been implemented.');
  }
}
