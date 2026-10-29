import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:true_compass/true_compass.dart';

/// A scriptable platform: tests push raw events and inspect lifecycle.
class FakePlatform extends TrueCompassPlatform with MockPlatformInterfaceMixin {
  FakePlatform({this.availability = CompassAvailability.available});

  CompassAvailability availability;
  RawSensorConfig? lastConfig;
  int listens = 0;
  int cancels = 0;
  late StreamController<Map<String, Object?>> controller;

  bool get active => listens > cancels;

  void send(Map<String, Object?> event) => controller.add(event);

  /// Flat device whose top edge points at [heading] degrees.
  void sendFlat(double heading, {int rotation = 0}) =>
      send(flatEvent(heading, rotation: rotation));

  static Map<String, Object?> flatEvent(double heading, {int rotation = 0}) {
    // alpha is counter-clockwise, heading clockwise.
    final m = OrientationMath.rotationMatrixFromEuler(-heading, 0, 0);
    return {'kind': 'matrix', 'matrix': m, 'screenRotation': rotation};
  }

  @override
  Future<CompassAvailability> checkAvailability() async => availability;

  @override
  Future<CompassAvailability> requestPermission() async {
    if (availability == CompassAvailability.permissionRequired) {
      availability = CompassAvailability.available;
    }
    return availability;
  }

  @override
  Stream<Map<String, Object?>> rawEvents(RawSensorConfig config) {
    lastConfig = config;
    controller = StreamController<Map<String, Object?>>(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    return controller.stream;
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);
