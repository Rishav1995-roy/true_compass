import 'package:flutter/material.dart';
import 'package:true_compass/true_compass.dart';

/// Theming, builders and the target marker, driven by a slider heading.
class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({
    super.key,
    this.initialHeading = 40,
    this.initialPreset = 'light',
  });

  final double initialHeading;
  final String initialPreset;

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  late double _heading = widget.initialHeading;
  late String _preset = widget.initialPreset;
  bool _degrees = false;
  bool _intercardinals = true;
  bool _target = true;
  bool _customNeedle = false;
  double _ticks = 72;

  CompassTheme _theme(BuildContext context) {
    final base = switch (_preset) {
      'dark' => const CompassTheme.dark(),
      'scheme' => CompassTheme.fromColorScheme(Theme.of(context).colorScheme),
      'forest' => const CompassTheme(
          dialColor: Color(0xFFEAF3E6),
          dialGradientEdge: Color(0xFFCFE3C8),
          borderColor: Color(0xFF2F5D3A),
          borderWidth: 6,
          tickColor: Color(0xFF5E8B67),
          majorTickColor: Color(0xFF1F3D27),
          northColor: Color(0xFFB4452A),
          needleColor: Color(0xFFB4452A),
          needleTailColor: Color(0xFF2F5D3A),
          hubColor: Color(0xFF1F3D27),
          targetColor: Color(0xFFD99A00),
        ),
      _ => const CompassTheme(),
    };
    return base.copyWith(
      showDegreeLabels: _degrees,
      showIntercardinals: _intercardinals,
      tickCount: _ticks.round(),
      showNeedle: !_customNeedle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CompassView(
            heading: _heading,
            size: 280,
            theme: theme,
            targetBearing: _target ? 118 : null,
            needleBuilder: _customNeedle
                ? (context, radius, theme) => Icon(
                      Icons.navigation,
                      size: radius * 0.9,
                      color: theme.needleColor,
                    )
                : null,
            centerBuilder: (context, h) => Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Text(
                '${h.round()}°',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.majorTickColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Heading ${_heading.round()}°'),
        Slider(
          min: 0,
          max: 359,
          value: _heading,
          onChanged: (v) => setState(() => _heading = v),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'dark', label: Text('Dark')),
            ButtonSegment(value: 'scheme', label: Text('Scheme')),
            ButtonSegment(value: 'forest', label: Text('Moss')),
          ],
          selected: {_preset},
          onSelectionChanged: (s) => setState(() => _preset = s.first),
        ),
        SwitchListTile(
          title: const Text('Degree labels'),
          value: _degrees,
          onChanged: (v) => setState(() => _degrees = v),
        ),
        SwitchListTile(
          title: const Text('Intercardinal labels'),
          value: _intercardinals,
          onChanged: (v) => setState(() => _intercardinals = v),
        ),
        SwitchListTile(
          title: const Text('Target marker (e.g. Qibla)'),
          value: _target,
          onChanged: (v) => setState(() => _target = v),
        ),
        SwitchListTile(
          title: const Text('Custom needleBuilder'),
          value: _customNeedle,
          onChanged: (v) => setState(() => _customNeedle = v),
        ),
        ListTile(
          title: Text('Ticks: ${_ticks.round()}'),
          subtitle: Slider(
            min: 12,
            max: 120,
            divisions: 27,
            value: _ticks,
            onChanged: (v) => setState(() => _ticks = v),
          ),
        ),
      ],
    );
  }
}
