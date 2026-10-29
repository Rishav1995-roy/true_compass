import 'dart:async';

import '../true_compass_platform_interface.dart';
import 'models.dart';
import 'options.dart';
import 'pipeline.dart';

/// Compass heading stream with magnetic and true north.
///
/// ```dart
/// final compass = TrueCompass(
///   options: CompassOptions(
///     location: CompassLocation(latitude: 48.85, longitude: 2.35),
///   ),
/// );
/// compass.headings.listen((h) => print(h.trueHeading));
/// ```
///
/// The sensors run only while at least one of [headings], [accuracyChanges]
/// or [calibrationNeeded] has a listener, so a forgotten instance does not
/// drain the battery. Call [dispose] when done.
class TrueCompass {
  /// Creates a compass. [platform] and [clock] are for tests.
  TrueCompass({
    CompassOptions options = const CompassOptions(),
    TrueCompassPlatform? platform,
    DateTime Function()? clock,
  })  : _options = options,
        _platform = platform,
        _clock = clock ?? DateTime.now {
    _headings = StreamController<CompassHeading>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    _accuracy = StreamController<CompassAccuracy>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    _calibration = StreamController<bool>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  final CompassOptions _options;
  final TrueCompassPlatform? _platform;
  final DateTime Function() _clock;

  late final StreamController<CompassHeading> _headings;
  late final StreamController<CompassAccuracy> _accuracy;
  late final StreamController<bool> _calibration;

  HeadingPipeline? _pipeline;
  StreamSubscription<Map<String, Object?>>? _subscription;
  DateTime? _lastEmit;
  CompassLocation? _location;
  bool _disposed = false;

  /// The latest emitted heading, or `null` before the first one.
  CompassHeading? latest;

  TrueCompassPlatform get _impl => _platform ?? TrueCompassPlatform.instance;

  /// The options this compass was created with.
  CompassOptions get options => _options;

  /// Heading samples, at most one per `CompassOptions.updateInterval`.
  Stream<CompassHeading> get headings => _headings.stream;

  /// Emits whenever the sensor accuracy level changes.
  Stream<CompassAccuracy> get accuracyChanges => _accuracy.stream;

  /// Emits `true` when the compass needs calibration and `false` once it is
  /// good again. Only changes are emitted.
  Stream<bool> get calibrationNeeded => _calibration.stream;

  /// Whether the compass can be used on this device.
  Future<CompassAvailability> checkAvailability() => _impl.checkAvailability();

  /// Asks for sensor permission where required (iOS Safari). Must be called
  /// from a user gesture such as a button tap.
  Future<CompassAvailability> requestPermission() => _impl.requestPermission();

  /// Sets or clears the location used to compute true north. Takes effect on
  /// the next sample, also while streaming.
  void setLocation(CompassLocation? location) {
    _location = location;
    _pipeline?.setLocation(location);
  }

  int get _listeners =>
      (_headings.hasListener ? 1 : 0) +
      (_accuracy.hasListener ? 1 : 0) +
      (_calibration.hasListener ? 1 : 0);

  void _onListen() {
    if (_subscription != null || _disposed) return;
    final pipeline = HeadingPipeline(_options, clock: _clock);
    if (_location != null) pipeline.setLocation(_location);
    _pipeline = pipeline;
    _lastEmit = null;
    _subscription = _impl
        .rawEvents(
          RawSensorConfig(
            interval: _options.updateInterval,
            compensateScreenOrientation: _options.compensateScreenOrientation,
          ),
        )
        .listen(_onEvent, onError: _onError);
  }

  void _onCancel() {
    if (_listeners > 0) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pipeline = null;
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!_headings.isClosed) _headings.addError(error, stackTrace);
  }

  bool? _lastCalibration;

  void _onEvent(Map<String, Object?> event) {
    final pipeline = _pipeline;
    if (pipeline == null) return;
    final kind = event['kind'];
    if (kind == 'accuracy' || kind == 'calibration') {
      _publishAccuracy(pipeline.processAccuracyEvent(event));
      return;
    }
    final heading = pipeline.processSample(event);
    if (heading == null) return;
    _publishAccuracy(_syncAccuracy(pipeline));
    final now = _clock();
    final last = _lastEmit;
    if (last != null && now.difference(last) < _options.updateInterval) return;
    _lastEmit = now;
    latest = heading;
    _headings.add(heading);
  }

  CompassAccuracy? _lastAccuracy;

  CompassAccuracy? _syncAccuracy(HeadingPipeline pipeline) =>
      pipeline.accuracy == _lastAccuracy ? null : pipeline.accuracy;

  void _publishAccuracy(CompassAccuracy? accuracy) {
    if (accuracy == null || accuracy == _lastAccuracy) return;
    _lastAccuracy = accuracy;
    _accuracy.add(accuracy);
    final needs = accuracy.needsCalibration;
    if (needs != _lastCalibration && accuracy != CompassAccuracy.unknown) {
      _lastCalibration = needs;
      _calibration.add(needs);
    }
  }

  /// Stops the sensors and closes all streams.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _headings.close();
    await _accuracy.close();
    await _calibration.close();
  }
}
