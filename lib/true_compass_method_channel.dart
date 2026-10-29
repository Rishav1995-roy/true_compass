import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models.dart';
import 'true_compass_platform_interface.dart';

/// [TrueCompassPlatform] backed by a method and an event channel
/// (Android and iOS).
class MethodChannelTrueCompass extends TrueCompassPlatform {
  /// Channel for one-shot calls.
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('true_compass/methods');

  /// Channel for sensor events.
  @visibleForTesting
  final EventChannel eventChannel = const EventChannel('true_compass/events');

  @override
  Future<CompassAvailability> checkAvailability() async {
    final name = await methodChannel.invokeMethod<String>('checkAvailability');
    return _parse(name);
  }

  @override
  Future<CompassAvailability> requestPermission() async {
    final name = await methodChannel.invokeMethod<String>('requestPermission');
    return _parse(name);
  }

  @override
  Stream<Map<String, Object?>> rawEvents(RawSensorConfig config) {
    return EventChannel(
      eventChannel.name,
      eventChannel.codec,
    ).receiveBroadcastStream(<String, Object?>{
      'intervalMicros': config.interval.inMicroseconds,
      'compensateScreenOrientation': config.compensateScreenOrientation,
    }).map((event) => Map<String, Object?>.from(event as Map));
  }

  static CompassAvailability _parse(String? name) {
    for (final value in CompassAvailability.values) {
      if (value.name == name) return value;
    }
    return CompassAvailability.unsupported;
  }
}
