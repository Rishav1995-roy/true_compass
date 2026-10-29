import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

import 'support/fake_platform.dart';

class Clock {
  DateTime now = DateTime.utc(2026, 6, 1);
  DateTime call() => now;
  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
}

void main() {
  late FakePlatform platform;
  late Clock clock;

  TrueCompass make([CompassOptions? options]) => TrueCompass(
        options: options ??
            const CompassOptions(
              updateInterval: Duration.zero,
              smoothing: CompassSmoothing.none(),
            ),
        platform: platform,
        clock: clock.call,
      );

  setUp(() {
    platform = FakePlatform();
    clock = Clock();
  });

  // Core problem 1: wrong / unstable headings.
  group('CORE-1 stable, valid headings', () {
    test('CORE-1a headings are never negative (flutter_compass #75, #91)',
        () async {
      final compass = make();
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      for (final h in [-10.0, -0.0, -359.0, 725.0, 0.0]) {
        platform.send({'kind': 'heading', 'heading': h, 'compensated': true});
      }
      await pump();
      expect(got, [350, 0, 1, 5, 0]);
      expect(got.every((v) => v >= 0 && v < 360 && !v.isNegative), isTrue);
      await sub.cancel();
    });

    test('CORE-1b NaN / infinite samples are dropped, not crashed on (#109)',
        () async {
      final compass = make();
      final got = <CompassHeading>[];
      final errors = <Object>[];
      final sub = compass.headings.listen(got.add, onError: errors.add);
      platform.send(
          {'kind': 'heading', 'heading': double.nan, 'compensated': true});
      platform.send(
          {'kind': 'heading', 'heading': double.infinity, 'compensated': true});
      platform.send({'kind': 'heading', 'heading': null, 'compensated': true});
      platform.send({
        'kind': 'matrix',
        'matrix': [double.nan, 0, 0, 0, 1, 0, 0, 0, 1],
        'screenRotation': 0,
      });
      platform.send({
        'kind': 'euler',
        'alpha': null,
        'beta': 0,
        'gamma': 0,
        'absolute': true
      });
      platform.send({'kind': 'unknown'});
      platform.sendFlat(42);
      await pump();
      expect(errors, isEmpty);
      expect(got, hasLength(1));
      expect(got.single.magneticHeading, closeTo(42, 1e-6));
      await sub.cancel();
    });

    test(
        'CORE-1c smoothing across the 359/1 wrap never swings the long way (#73, #82)',
        () async {
      final compass = make(
        const CompassOptions(
          updateInterval: Duration.zero,
          smoothing: CompassSmoothing.lowPass(alpha: 0.4),
        ),
      );
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      for (var i = 0; i < 30; i++) {
        platform.sendFlat(i.isEven ? 359 : 1);
      }
      await pump();
      expect(got, hasLength(30));
      for (final h in got) {
        expect(Angles.shortestDelta(h, 0).abs(), lessThan(3), reason: '$h');
      }
      await sub.cancel();
    });

    test('CORE-1d a slow sweep through north is monotonic with no jump',
        () async {
      final compass = make(
        const CompassOptions(
          updateInterval: Duration.zero,
          smoothing: CompassSmoothing.circularAverage(window: 4),
        ),
      );
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      for (var d = 340.0; d <= 380; d += 2) {
        platform.sendFlat(d);
      }
      await pump();
      for (var i = 1; i < got.length; i++) {
        expect(
            Angles.shortestDelta(got[i - 1], got[i]), inInclusiveRange(0, 4));
      }
      await sub.cancel();
    });

    test(
        'CORE-1e same pose gives the same heading on every platform path (#105)',
        () async {
      // Android matrix, web Euler and iOS heading events for a phone held flat
      // with its top edge pointing at 70 degrees.
      final compass = make();
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      platform.sendFlat(70);
      platform.send({
        'kind': 'euler',
        'alpha': 290.0,
        'beta': 0.0,
        'gamma': 0.0,
        'absolute': true,
        'screenRotation': 0
      });
      platform.send({'kind': 'heading', 'heading': 70.0, 'compensated': true});
      platform.send({
        'kind': 'heading',
        'heading': 70.0,
        'compensated': false,
        'screenRotation': 0
      });
      await pump();
      expect(got, hasLength(4));
      for (final h in got) {
        expect(h, closeTo(70, 1e-6));
      }
      await sub.cancel();
    });

    test('CORE-1f upright phone, camera mode, is not stuck at 0 (#120)',
        () async {
      final compass = make();
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      // Upright, back camera facing east.
      platform.send({
        'kind': 'matrix',
        'matrix': [0.0, 0, -1, -1, 0, 0, 0, 1, 0],
        'screenRotation': 0,
      });
      await pump();
      expect(got.single, closeTo(90, 1e-9));
      await sub.cancel();
    });

    test('web without a north reference (relative orientation) is ignored',
        () async {
      final compass = make();
      final got = <CompassHeading>[];
      final sub = compass.headings.listen(got.add);
      platform.send({
        'kind': 'euler',
        'alpha': 10.0,
        'beta': 0.0,
        'gamma': 0.0,
        'absolute': false
      });
      await pump();
      expect(got, isEmpty);
      await sub.cancel();
    });
  });

  // Core problem 2: true north.
  group('CORE-2 true north', () {
    test(
        'CORE-2a trueHeading = magnetic + WMM declination for the supplied location',
        () async {
      final compass = make(
        const CompassOptions(
          updateInterval: Duration.zero,
          smoothing: CompassSmoothing.none(),
          location: CompassLocation(latitude: 47.6, longitude: -122.3),
        ),
      );
      final got = <CompassHeading>[];
      final sub = compass.headings.listen(got.add);
      platform.sendFlat(10);
      await pump();
      final expected = MagneticDeclination.at(
        latitude: 47.6,
        longitude: -122.3,
        date: clock.now,
      );
      expect(expected, greaterThan(10));
      expect(got.single.declination, closeTo(expected, 1e-9));
      expect(got.single.trueHeading,
          closeTo(Angles.normalize360(10 + expected), 1e-6));
      expect(got.single.magneticHeading, closeTo(10, 1e-6));
      expect(got.single.bestHeading, got.single.trueHeading);
      await sub.cancel();
    });

    test(
        'CORE-2b without a location trueHeading is null (no hidden location dependency)',
        () async {
      final compass = make();
      final got = <CompassHeading>[];
      final sub = compass.headings.listen(got.add);
      platform.sendFlat(10);
      await pump();
      expect(got.single.trueHeading, isNull);
      expect(got.single.bestHeading, closeTo(10, 1e-6));
      await sub.cancel();
    });

    test(
        'CORE-2c setLocation applies while streaming; true heading wraps past 360',
        () async {
      final compass = make();
      final got = <CompassHeading>[];
      final sub = compass.headings.listen(got.add);
      platform.sendFlat(355);
      await pump();
      compass.setLocation(
          const CompassLocation(latitude: 47.6, longitude: -122.3));
      platform.sendFlat(355);
      await pump();
      expect(got[0].trueHeading, isNull);
      expect(got[1].trueHeading, inInclusiveRange(0, 360));
      expect(got[1].trueHeading, lessThan(30));
      compass.setLocation(null);
      platform.sendFlat(355);
      await pump();
      expect(got[2].trueHeading, isNull);
      await sub.cancel();
    });
  });

  // Core problem 3: accuracy, calibration, update rate.
  group('CORE-3 accuracy, calibration and update rate', () {
    test(
        'CORE-3a Android accuracy statuses become accuracy + calibration events (#97, #81, #106)',
        () async {
      final compass = make();
      final acc = <CompassAccuracy>[];
      final cal = <bool>[];
      final a = compass.accuracyChanges.listen(acc.add);
      final c = compass.calibrationNeeded.listen(cal.add);
      for (final s in [0, 0, 1, 2, 3, 3, 0]) {
        platform.send({'kind': 'accuracy', 'status': s});
      }
      await pump();
      expect(acc, [
        CompassAccuracy.unreliable,
        CompassAccuracy.low,
        CompassAccuracy.medium,
        CompassAccuracy.high,
        CompassAccuracy.unreliable,
      ]);
      // Only changes of the boolean are emitted.
      expect(cal, [true, false, true]);
      await a.cancel();
      await c.cancel();
    });

    test('CORE-3b iOS heading error and calibration request', () async {
      final compass = make();
      final acc = <CompassAccuracy>[];
      final cal = <bool>[];
      final headings = <CompassHeading>[];
      final subs = [
        compass.accuracyChanges.listen(acc.add),
        compass.calibrationNeeded.listen(cal.add),
        compass.headings.listen(headings.add),
      ];
      platform.send({
        'kind': 'heading',
        'heading': 1.0,
        'compensated': true,
        'errorDegrees': 5.0
      });
      platform.send({
        'kind': 'heading',
        'heading': 2.0,
        'compensated': true,
        'errorDegrees': -1.0
      });
      platform.send({'kind': 'calibration'});
      platform.send({
        'kind': 'heading',
        'heading': 3.0,
        'compensated': true,
        'errorDegrees': 30.0
      });
      await pump();
      expect(acc, [
        CompassAccuracy.high,
        CompassAccuracy.unreliable,
        CompassAccuracy.low,
      ]);
      expect(cal, [false, true]);
      expect(headings[0].accuracy, CompassAccuracy.high);
      expect(headings[1].needsCalibration, isTrue);
      expect(headings[0].errorDegrees, 5.0);
      for (final s in subs) {
        await s.cancel();
      }
    });

    test('CORE-3c headings carry the latest accuracy', () async {
      final compass = make();
      final got = <CompassHeading>[];
      final sub = compass.headings.listen(got.add);
      platform.send({'kind': 'accuracy', 'status': 1});
      platform.sendFlat(5);
      await pump();
      expect(got.single.accuracy, CompassAccuracy.low);
      await sub.cancel();
    });

    test('CORE-3d update interval is configurable (#96)', () async {
      final compass = make(
        const CompassOptions(
          updateInterval: Duration(milliseconds: 100),
          smoothing: CompassSmoothing.none(),
        ),
      );
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      platform.sendFlat(1);
      await pump();
      // 10 samples 20 ms apart: only the first and one per 100 ms get through.
      for (var i = 2; i <= 11; i++) {
        clock.advance(20);
        platform.sendFlat(i.toDouble());
        await pump();
      }
      expect(got.length, inInclusiveRange(2, 3));
      expect(got.first, closeTo(1, 1e-6));
      expect(platform.lastConfig!.interval, const Duration(milliseconds: 100));
      await sub.cancel();
    });

    test(
        'CORE-3e zero interval emits every sample; smoothing still sees throttled-out samples',
        () async {
      final compass = make(
        const CompassOptions(
          updateInterval: Duration(seconds: 1),
          smoothing: CompassSmoothing.circularAverage(window: 3),
        ),
      );
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      platform.sendFlat(10);
      platform.sendFlat(20);
      platform.sendFlat(30);
      await pump();
      clock.advance(1500);
      platform.sendFlat(40);
      await pump();
      expect(got, hasLength(2));
      // Mean of the last three samples (20, 30, 40), not just the emitted one.
      expect(got[1], closeTo(30, 1e-6));
      await sub.cancel();
    });
  });

  group('availability, lifecycle, screen rotation', () {
    test('availability and permission pass through', () async {
      platform.availability = CompassAvailability.permissionRequired;
      final compass = make();
      expect(await compass.checkAvailability(),
          CompassAvailability.permissionRequired);
      expect(await compass.requestPermission(), CompassAvailability.available);
      platform.availability = CompassAvailability.noSensor;
      expect(await compass.checkAvailability(), CompassAvailability.noSensor);
    });

    test('sensors run only while someone listens (battery)', () async {
      final compass = make();
      expect(platform.listens, 0);
      final a = compass.headings.listen((_) {});
      final b = compass.accuracyChanges.listen((_) {});
      expect(platform.listens, 1,
          reason: 'one native subscription for all streams');
      await a.cancel();
      await pump();
      expect(platform.active, isTrue,
          reason: 'accuracy stream still listening');
      await b.cancel();
      await pump();
      expect(platform.active, isFalse);
      final c = compass.headings.listen((_) {});
      expect(platform.listens, 2);
      await c.cancel();
      await compass.dispose();
    });

    test('latest holds the last heading and dispose closes streams', () async {
      final compass = make();
      final done = Completer<void>();
      compass.headings.listen((_) {}, onDone: done.complete);
      platform.sendFlat(33);
      await pump();
      expect(compass.latest!.magneticHeading, closeTo(33, 1e-6));
      await compass.dispose();
      await done.future;
      expect(platform.active, isFalse);
    });

    test('screen rotation is compensated, and can be turned off (#85)',
        () async {
      // Flat phone in landscape (top edge west), user facing north.
      final landscape = {
        'kind': 'matrix',
        'matrix': [0.0, -1, 0, 1, 0, 0, 0, 0, 1],
        'screenRotation': 90,
      };
      final on = make();
      final onGot = <double>[];
      final s1 = on.headings.listen((h) => onGot.add(h.magneticHeading));
      platform.send(landscape);
      await pump();
      expect(onGot.single, closeTo(0, 1e-9));
      await s1.cancel();

      platform = FakePlatform();
      final off = make(
        const CompassOptions(
          updateInterval: Duration.zero,
          smoothing: CompassSmoothing.none(),
          compensateScreenOrientation: false,
        ),
      );
      final offGot = <double>[];
      final s2 = off.headings.listen((h) => offGot.add(h.magneticHeading));
      platform.send(landscape);
      await pump();
      expect(offGot.single, closeTo(270, 1e-9));
      expect(platform.lastConfig!.compensateScreenOrientation, isFalse);
      await s2.cancel();
    });

    test('iOS Safari webkitCompassHeading follows the screen rotation',
        () async {
      final compass = make();
      final got = <double>[];
      final sub = compass.headings.listen((h) => got.add(h.magneticHeading));
      platform.send({
        'kind': 'heading',
        'heading': 270.0,
        'compensated': false,
        'screenRotation': 90
      });
      await pump();
      expect(got.single, closeTo(0, 1e-9));
      await sub.cancel();
    });

    test('platform errors surface on the heading stream', () async {
      final compass = make();
      final errors = <Object>[];
      final sub = compass.headings.listen((_) {}, onError: errors.add);
      platform.controller.addError(StateError('no sensor'));
      await pump();
      expect(errors, hasLength(1));
      await sub.cancel();
    });
  });

  group('models', () {
    test('CompassAccuracy mappings', () {
      expect(CompassAccuracy.fromAndroidStatus(null), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromAndroidStatus(-1), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromErrorDegrees(null), CompassAccuracy.unknown);
      expect(CompassAccuracy.fromErrorDegrees(10), CompassAccuracy.high);
      expect(CompassAccuracy.fromErrorDegrees(20), CompassAccuracy.medium);
      expect(CompassAccuracy.fromErrorDegrees(40), CompassAccuracy.low);
      expect(CompassAccuracy.fromErrorDegrees(90), CompassAccuracy.unreliable);
      expect(CompassAccuracy.unknown.needsCalibration, isFalse);
      expect(CompassAccuracy.medium.needsCalibration, isFalse);
    });

    test('CompassHeading normalizes and picks references', () {
      final h = CompassHeading(magneticHeading: -10, trueHeading: 5);
      expect(h.magneticHeading, 350);
      expect(h.headingFor(trueNorth: false), 350);
      expect(h.headingFor(trueNorth: true), 5);
      expect(h.toString(), contains('350.0'));
    });

    test('CompassOptions.copyWith and CompassLocation equality', () {
      const a = CompassLocation(latitude: 1, longitude: 2);
      expect(a, const CompassLocation(latitude: 1, longitude: 2));
      expect(a.hashCode,
          const CompassLocation(latitude: 1, longitude: 2).hashCode);
      final o = const CompassOptions().copyWith(
        updateInterval: Duration.zero,
        location: a,
        compensateScreenOrientation: false,
        smoothing: const CompassSmoothing.none(),
      );
      expect(o.updateInterval, Duration.zero);
      expect(o.location, a);
      expect(o.compensateScreenOrientation, isFalse);
    });
  });
}
