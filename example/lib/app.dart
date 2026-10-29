import 'package:flutter/material.dart';
import 'package:true_compass/true_compass.dart';

import 'customize_screen.dart';
import 'declination_screen.dart';
import 'live_screen.dart';

/// The example app. [simulated] forces the simulated heading stream.
class ExampleApp extends StatelessWidget {
  const ExampleApp({
    super.key,
    this.simulated = false,
    this.brightness = Brightness.light,
    this.initialTab = 0,
    this.simulatedAccuracy = CompassAccuracy.high,
    this.customizePreset = 'light',
  });

  final bool simulated;
  final Brightness brightness;
  final int initialTab;
  final CompassAccuracy simulatedAccuracy;
  final String customizePreset;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'true_compass',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2563EB),
          brightness: brightness,
          useMaterial3: true,
        ),
        home: Home(
          simulated: simulated,
          initialTab: initialTab,
          simulatedAccuracy: simulatedAccuracy,
          customizePreset: customizePreset,
        ),
      );
}

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.simulated,
    this.initialTab = 0,
    this.simulatedAccuracy = CompassAccuracy.high,
    this.customizePreset = 'light',
  });

  final bool simulated;
  final int initialTab;
  final CompassAccuracy simulatedAccuracy;
  final String customizePreset;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      LiveScreen(
        forceSimulated: widget.simulated,
        simulatedAccuracy: widget.simulatedAccuracy,
      ),
      CustomizeScreen(initialPreset: widget.customizePreset),
      const DeclinationScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('true_compass')),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.palette), label: 'Customize'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Declination'),
        ],
      ),
    );
  }
}
