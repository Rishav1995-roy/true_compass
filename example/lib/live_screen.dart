import 'dart:async';

import 'package:flutter/material.dart';
import 'package:true_compass/true_compass.dart';

import 'cities.dart';
import 'simulator.dart';

/// Live heading from the device (or a simulated stream) with every option.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    this.forceSimulated = false,
    this.simulatedAccuracy = CompassAccuracy.high,
  });

  /// Skips the sensor check and shows the simulated stream (used for the
  /// demo GIF and on emulators).
  final bool forceSimulated;

  /// Accuracy reported by the simulated stream.
  final CompassAccuracy simulatedAccuracy;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  City _city = cities.first;
  bool _useLocation = true;
  bool _trueNorth = true;
  bool _compensate = true;
  late bool _simulate = widget.forceSimulated;
  double _intervalMs = 50;
  String _smoothing = 'low-pass';
  CompassAvailability? _availability;

  TrueCompass? _compass;
  Stream<CompassHeading>? _stream;
  StreamSubscription<bool>? _calibration;
  bool _needsCalibration = false;
  CompassHeading? _latest;
  StreamSubscription<CompassHeading>? _readout;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  CompassSmoothing get _smoothingStrategy => switch (_smoothing) {
        'none' => const CompassSmoothing.none(),
        'average' => const CompassSmoothing.circularAverage(window: 8),
        _ => const CompassSmoothing.lowPass(alpha: 0.25),
      };

  Future<void> _restart() async {
    await _calibration?.cancel();
    await _readout?.cancel();
    await _compass?.dispose();
    final decl = _useLocation
        ? MagneticDeclination.at(
            latitude: _city.location.latitude,
            longitude: _city.location.longitude,
          )
        : null;
    if (_simulate) {
      final stream = simulatedHeadings(
        declination: decl ?? 0,
        accuracy: widget.simulatedAccuracy,
      ).asBroadcastStream(onCancel: (sub) => sub.cancel());
      _compass = null;
      _stream = stream;
    } else {
      final compass = TrueCompass(
        options: CompassOptions(
          updateInterval: Duration(milliseconds: _intervalMs.round()),
          smoothing: _smoothingStrategy,
          compensateScreenOrientation: _compensate,
          location: _useLocation ? _city.location : null,
        ),
      );
      _compass = compass;
      _stream = compass.headings;
      _availability = await compass.checkAvailability();
      _calibration = compass.calibrationNeeded.listen((needs) {
        if (mounted) setState(() => _needsCalibration = needs);
      });
    }
    _readout = _stream!.listen((h) {
      if (mounted) setState(() => _latest = h);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _calibration?.cancel();
    _readout?.cancel();
    _compass?.dispose();
    super.dispose();
  }

  String _deg(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)}°';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = _latest;
    final stream = _stream;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_simulate)
          _Banner(
            color: scheme.tertiaryContainer,
            icon: Icons.science_outlined,
            text: 'Simulated heading stream (no sensor in use).',
          ),
        if (!_simulate &&
            _availability != null &&
            _availability != CompassAvailability.available)
          _Banner(
            color: scheme.errorContainer,
            icon: Icons.sensors_off,
            text: 'Compass: ${_availability!.name}',
            action: _availability == CompassAvailability.permissionRequired
                ? TextButton(
                    onPressed: () async {
                      final result = await _compass?.requestPermission();
                      setState(() => _availability = result);
                      await _restart();
                    },
                    child: const Text('Allow'),
                  )
                : null,
          ),
        if (_needsCalibration || h?.needsCalibration == true)
          _Banner(
            color: scheme.errorContainer,
            icon: Icons.all_inclusive,
            text: 'Calibrate: wave the phone in a figure of eight.',
          ),
        const SizedBox(height: 8),
        Center(
          child: stream == null
              ? const CircularProgressIndicator()
              : CompassView.stream(
                  stream: stream,
                  size: 280,
                  trueNorth: _trueNorth,
                  centerBuilder: (context, heading) => Padding(
                    padding: const EdgeInsets.only(top: 110),
                    child: Text(
                      '${heading.round()}°\n${Angles.cardinal8(heading)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Stat('Magnetic', _deg(h?.magneticHeading)),
            _Stat('True', _deg(h?.trueHeading)),
            _Stat('Declination', _deg(h?.declination)),
            _Stat('Accuracy', h?.accuracy.name ?? '--'),
          ],
        ),
        const Divider(height: 32),
        SwitchListTile(
          title: const Text('Simulate (no sensor)'),
          value: _simulate,
          onChanged: (v) {
            _simulate = v;
            _restart();
          },
        ),
        SwitchListTile(
          title: const Text('Use true north'),
          subtitle: const Text('Needs a location for the declination'),
          value: _trueNorth && _useLocation,
          onChanged:
              _useLocation ? (v) => setState(() => _trueNorth = v) : null,
        ),
        SwitchListTile(
          title: const Text('Supply a location'),
          value: _useLocation,
          onChanged: (v) {
            _useLocation = v;
            _restart();
          },
        ),
        ListTile(
          title: const Text('Location'),
          trailing: DropdownButton<City>(
            value: _city,
            items: [
              for (final c in cities)
                DropdownMenuItem(value: c, child: Text(c.name)),
            ],
            onChanged: _useLocation
                ? (c) {
                    _city = c!;
                    _restart();
                  }
                : null,
          ),
        ),
        SwitchListTile(
          title: const Text('Compensate screen rotation'),
          value: _compensate,
          onChanged: (v) {
            _compensate = v;
            _restart();
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Smoothing'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'none', label: Text('None')),
              ButtonSegment(value: 'low-pass', label: Text('Low-pass')),
              ButtonSegment(value: 'average', label: Text('Average')),
            ],
            selected: {_smoothing},
            onSelectionChanged: (s) {
              _smoothing = s.first;
              _restart();
            },
          ),
        ),
        ListTile(
          title: Text('Update interval: ${_intervalMs.round()} ms'),
          subtitle: Slider(
            min: 0,
            max: 500,
            divisions: 25,
            value: _intervalMs,
            onChanged: (v) => setState(() => _intervalMs = v),
            onChangeEnd: (_) => _restart(),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.action,
  });

  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        child: ListTile(
          leading: Icon(icon),
          title: Text(text),
          trailing: action,
          dense: true,
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
}
