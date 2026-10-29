import 'package:flutter/material.dart';
import 'package:true_compass/true_compass.dart';

import 'cities.dart';

/// Offline WMM2025 declination for sample cities.
class DeclinationScreen extends StatelessWidget {
  const DeclinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final inWindow = now.isBefore(MagneticDeclination.validUntil);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'World Magnetic Model 2025, computed on the device. '
          'True heading = magnetic heading + declination.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!inWindow)
          const Text('The bundled model is past its 2030 validity window.'),
        const SizedBox(height: 12),
        for (final c in cities)
          Builder(
            builder: (context) {
              final field = MagneticDeclination.field(
                latitude: c.location.latitude,
                longitude: c.location.longitude,
                date: now,
              );
              final d = field.declination;
              return ListTile(
                title: Text(c.name),
                subtitle: Text('dip ${field.inclination.toStringAsFixed(1)}°'),
                trailing: Text(
                  '${d >= 0 ? '+' : ''}${d.toStringAsFixed(2)}° ${d >= 0 ? 'E' : 'W'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            },
          ),
      ],
    );
  }
}
