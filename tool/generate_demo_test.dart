@Tags(['demo'])
library;

// Renders doc/demo.gif frames and screenshots deterministically, without a
// device. The heading stream is SIMULATED (example/lib/simulator.dart).
//
//   flutter test --tags demo tool/generate_demo_test.dart
//   tool/make_demo.sh            # assembles doc/demo.gif with ffmpeg

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/app.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      File('tool/fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

const _frames = 84; // 7 s at 12 fps
const _fps = 12;

void main() {
  final boundaryKey = GlobalKey();

  Future<void> shot(WidgetTester tester, String path) async {
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes.buffer.asUint8List());
    });
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Let the simulated stream's last timer fire.
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> show(WidgetTester tester, Widget app) async {
    await teardown(tester);
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: app));
  }

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  testWidgets('demo frames (simulated heading stream)', (tester) async {
    await show(tester, const ExampleApp(simulated: true));
    final dir = Directory('build/demo_frames');
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        f.deleteSync();
      }
    }
    for (var i = 0; i < _frames; i++) {
      await shot(
          tester, 'build/demo_frames/f${i.toString().padLeft(3, '0')}.png');
      // Advance simulated time; the stream ticks every 50 ms.
      for (var t = 0; t < 1000 ~/ _fps; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(Duration(milliseconds: 1000 ~/ _fps % 50));
    }
    await teardown(tester);
  });

  testWidgets('screenshots', (tester) async {
    // Light: Live tab.
    await show(tester, const ExampleApp(simulated: true));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot(tester, 'doc/screenshot_light.png');

    // Dark with the calibration banner.
    await show(
      tester,
      const ExampleApp(
        simulated: true,
        brightness: Brightness.dark,
        simulatedAccuracy: CompassAccuracy.low,
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shot(tester, 'doc/screenshot_dark.png');

    // Customize tab with the custom palette.
    await show(
      tester,
      const ExampleApp(initialTab: 1, customizePreset: 'forest'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'doc/screenshot_custom.png');
    await teardown(tester);
  });
}
