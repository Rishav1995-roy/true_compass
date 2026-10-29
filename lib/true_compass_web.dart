import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/models.dart';
import 'true_compass_platform_interface.dart';

/// Web implementation built on `DeviceOrientationEvent`.
///
/// Chrome and Android browsers expose absolute orientation through the
/// `deviceorientationabsolute` event. iOS Safari exposes
/// `webkitCompassHeading` and requires a permission prompt that must be
/// started from a user gesture. Pages must be served over HTTPS.
class TrueCompassWeb extends TrueCompassPlatform {
  /// Registers this class as the web implementation.
  static void registerWith(Registrar registrar) {
    TrueCompassPlatform.instance = TrueCompassWeb();
  }

  bool _permissionGranted = false;

  JSObject? get _deviceOrientationEvent {
    final value = globalContext['DeviceOrientationEvent'];
    return value.isUndefinedOrNull ? null : value as JSObject;
  }

  bool get _needsPermission {
    final event = _deviceOrientationEvent;
    return event != null && event.has('requestPermission');
  }

  @override
  Future<CompassAvailability> checkAvailability() async {
    if (!web.window.isSecureContext) return CompassAvailability.insecureContext;
    if (_deviceOrientationEvent == null) return CompassAvailability.noSensor;
    if (_needsPermission && !_permissionGranted) {
      return CompassAvailability.permissionRequired;
    }
    return CompassAvailability.available;
  }

  @override
  Future<CompassAvailability> requestPermission() async {
    final availability = await checkAvailability();
    if (availability != CompassAvailability.permissionRequired) {
      return availability;
    }
    try {
      final promise = _deviceOrientationEvent!
          .callMethod<JSPromise<JSString>>('requestPermission'.toJS);
      final answer = (await promise.toDart).toDart;
      _permissionGranted = answer == 'granted';
      return _permissionGranted
          ? CompassAvailability.available
          : CompassAvailability.permissionDenied;
    } catch (_) {
      return CompassAvailability.permissionDenied;
    }
  }

  int _screenRotation() {
    try {
      return web.window.screen.orientation.angle;
    } catch (_) {
      return 0;
    }
  }

  @override
  Stream<Map<String, Object?>> rawEvents(RawSensorConfig config) {
    late StreamController<Map<String, Object?>> controller;
    JSFunction? absoluteListener;
    JSFunction? plainListener;

    double? number(JSObject event, String name) {
      final value = event[name];
      if (value.isUndefinedOrNull) return null;
      final n = (value as JSNumber).toDartDouble;
      return n.isFinite ? n : null;
    }

    void onEvent(web.Event raw, {required bool absoluteEvent}) {
      final event = raw as JSObject;
      final rotation = _screenRotation();
      final webkit = number(event, 'webkitCompassHeading');
      if (webkit != null) {
        controller.add({
          'kind': 'heading',
          'heading': webkit,
          'compensated': false,
          'screenRotation': rotation,
          // iOS Safari: webkitCompassAccuracy is degrees, negative = invalid.
          'errorDegrees': number(event, 'webkitCompassAccuracy'),
        });
        return;
      }
      final alpha = number(event, 'alpha');
      final beta = number(event, 'beta');
      final gamma = number(event, 'gamma');
      if (alpha == null || beta == null || gamma == null) return;
      final flag = event['absolute'];
      final absolute = absoluteEvent ||
          (!flag.isUndefinedOrNull && (flag as JSBoolean).toDart);
      controller.add({
        'kind': 'euler',
        'alpha': alpha,
        'beta': beta,
        'gamma': gamma,
        'absolute': absolute,
        'screenRotation': rotation,
      });
    }

    controller = StreamController<Map<String, Object?>>(
      onListen: () {
        absoluteListener =
            ((web.Event e) => onEvent(e, absoluteEvent: true)).toJS;
        plainListener =
            ((web.Event e) => onEvent(e, absoluteEvent: false)).toJS;
        web.window
            .addEventListener('deviceorientationabsolute', absoluteListener);
        web.window.addEventListener('deviceorientation', plainListener);
      },
      onCancel: () {
        if (absoluteListener != null) {
          web.window.removeEventListener(
              'deviceorientationabsolute', absoluteListener);
        }
        if (plainListener != null) {
          web.window.removeEventListener('deviceorientation', plainListener);
        }
      },
    );
    return controller.stream;
  }
}
