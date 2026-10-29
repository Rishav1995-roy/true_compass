# true_compass

[![pub version](https://img.shields.io/pub/v/true_compass.svg)](https://pub.dev/packages/true_compass)
[![pub points](https://img.shields.io/pub/points/true_compass)](https://pub.dev/packages/true_compass/score)
[![likes](https://img.shields.io/pub/likes/true_compass)](https://pub.dev/packages/true_compass)
[![popularity](https://img.shields.io/pub/popularity/true_compass)](https://pub.dev/packages/true_compass)
[![CI](https://github.com/Rishav1995-roy/true_compass/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/true_compass/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web-informational)

A Flutter compass that gives you **magnetic and true north**, tells you **when the sensor needs calibration**, smooths the 359 to 0 wrap correctly, follows **screen rotation**, and ships a **themeable dial**. True north comes from the World Magnetic Model (WMM2025) computed on the device in pure Dart: no network, no location plugin, no asset files.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/true_compass/main/doc/demo.gif)

> The GIF above is rendered from a **simulated** heading stream (a slow sweep with noise that crosses north), not captured from a device. It shows the `CompassView` widget and how it animates; the example app runs the same code against the real sensor.

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/true_compass/main/doc/screenshot_light.png" width="240" alt="Light dial">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/true_compass/main/doc/screenshot_dark.png" width="240" alt="Dark dial with calibration banner">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/true_compass/main/doc/screenshot_custom.png" width="240" alt="Customization screen">
</p>

## Why this package

[`flutter_compass`](https://pub.dev/packages/flutter_compass) is the most used compass plugin (last release 0.8.1, November 2024) and many apps depend on it. Its open issues are what this package was designed around:

| Problem (issue) | `flutter_compass` | `true_compass` |
|---|---|---|
| Android build fails: `android:attr/lStar not found` ([#112](https://github.com/hemanthrajv/flutter_compass/issues/112)), "Causes build failure" ([#117](https://github.com/hemanthrajv/flutter_compass/issues/117)), AGP 8 ([#104](https://github.com/hemanthrajv/flutter_compass/issues/104)), Kotlin ([#99](https://github.com/hemanthrajv/flutter_compass/issues/99)) | Open | No androidx or other Android dependencies at all, `namespace` set, one `build.gradle` that works with AGP 8 and 9. The example app builds in CI (Android and iOS jobs). |
| Swift Package Manager ([#126](https://github.com/hemanthrajv/flutter_compass/issues/126)) | Not supported at 0.8.1 | `Package.swift` and CocoaPods podspec, privacy manifest included |
| Negative headings ([#75](https://github.com/hemanthrajv/flutter_compass/issues/75), [#91](https://github.com/hemanthrajv/flutter_compass/issues/91)) | Open | Every heading is in `[0, 360)`; tested for negatives, overflow and `-0.0` |
| `NaN` crash ([#109](https://github.com/hemanthrajv/flutter_compass/issues/109)) | Open | Non-finite samples are dropped before they reach your code |
| Jumpy or laggy dial ([#73](https://github.com/hemanthrajv/flutter_compass/issues/73), [#82](https://github.com/hemanthrajv/flutter_compass/issues/82), [#89](https://github.com/hemanthrajv/flutter_compass/issues/89)) | Open | Low-pass and circular-average smoothing that handle the 359 to 1 wrap; `CompassView` animates the shortest arc |
| Compass stops after rotating the phone ([#85](https://github.com/hemanthrajv/flutter_compass/issues/85)), camera mode returns 0.0 on Android ([#120](https://github.com/hemanthrajv/flutter_compass/issues/120)) | Open | Screen-rotation compensation and flat-to-upright tilt blending, covered by unit tests |
| Android and iOS disagree ([#105](https://github.com/hemanthrajv/flutter_compass/issues/105)) | Open | All platforms are reduced to the same definition (clockwise degrees from magnetic north of the screen's top edge); a test feeds one pose through every platform path |
| How to detect accuracy / when to calibrate ([#97](https://github.com/hemanthrajv/flutter_compass/issues/97), [#81](https://github.com/hemanthrajv/flutter_compass/issues/81), [#106](https://github.com/hemanthrajv/flutter_compass/issues/106)) | Open | `accuracyChanges` and `calibrationNeeded` streams on one normalized scale |
| Refresh rate ([#96](https://github.com/hemanthrajv/flutter_compass/issues/96)) | Open | `CompassOptions.updateInterval` |
| Web ([#119](https://github.com/hemanthrajv/flutter_compass/issues/119)) | Open | `DeviceOrientationEvent`, iOS Safari permission flow |
| True north | Not provided | Offline WMM2025 declination |

Other options: [`compassx`](https://pub.dev/packages/compassx) (last release May 2024) and [`flutter_rotation_sensor`](https://pub.dev/packages/flutter_rotation_sensor) (a general orientation quaternion, not a compass API). `flutter_compass` is still a fine choice if you only need a quick magnetic heading on Android and iOS and your build already works.

## Features

- Magnetic heading and true heading on every sample
- True north from WMM2025 in pure Dart, verified against NOAA's published test values to 0.02 degrees; you supply the location, the package never asks for location permission
- Accuracy levels (`unreliable`, `low`, `medium`, `high`) and a `calibrationNeeded` stream
- `checkAvailability()` and `requestPermission()` (iOS Safari)
- Configurable update interval; sensors run only while something listens
- Smoothing: none, low-pass, circular average (all handle the 359 to 0 wrap)
- Screen-orientation compensation, switchable
- `CompassView`: themeable dial with custom needle, center and overlay builders, a target marker (Qibla, destination), semantics label, shortest-arc animation
- No third-party dependencies beyond `plugin_platform_interface` and `web`

## Platform support

| Android | iOS | Web | macOS / Windows / Linux |
|---|---|---|---|
| Yes (rotation vector sensor, minSdk 21) | Yes (CoreLocation heading, iOS 15+, Swift Package Manager and CocoaPods) | Yes (HTTPS, WASM compatible) | No |

CocoaPods trunk becomes read-only on 2026-12-02. This package ships a `Package.swift` so it keeps working when your app uses Swift Package Manager (the default in current Flutter).

## Installation

```sh
flutter pub add true_compass
```

Requires Dart `^3.6.0` and Flutter `>=3.27.0`. Tested on Flutter 3.27 and the latest stable.

### Platform setup

- **Android:** nothing to do. No permissions are needed.
- **iOS:** nothing to do for the magnetic heading. The package never requests location. Add your own `NSLocationWhenInUseUsageDescription` only if your app also reads GPS.
- **Web:** the page must be served over HTTPS (browsers hide motion sensors otherwise). On iOS Safari call `requestPermission()` from a tap handler. Desktop browsers have no compass.

## Quick start

```dart
import 'package:true_compass/true_compass.dart';

final compass = TrueCompass(
  options: const CompassOptions(
    // Optional. Needed for trueHeading. Any rough location works.
    location: CompassLocation(latitude: 48.8566, longitude: 2.3522),
  ),
);

compass.headings.listen((h) {
  print('magnetic ${h.magneticHeading.toStringAsFixed(1)}  '
      'true ${h.trueHeading?.toStringAsFixed(1)}  ${h.accuracy.name}');
});

// Show a dial.
CompassView.stream(stream: compass.headings, size: 280);

// Later:
await compass.dispose();
```

## Examples

### Check availability and ask for permission

```dart
final status = await compass.checkAvailability();
switch (status) {
  case CompassAvailability.available:
    break;
  case CompassAvailability.permissionRequired: // iOS Safari
    await compass.requestPermission(); // call from a button onPressed
  case CompassAvailability.noSensor:
  case CompassAvailability.insecureContext:
  case CompassAvailability.permissionDenied:
  case CompassAvailability.unsupported:
    // show a fallback
}
```

### Ask the user to calibrate

```dart
compass.calibrationNeeded.listen((needs) {
  if (needs) showFigureEightHint();
});
```

### Update rate and smoothing

```dart
TrueCompass(
  options: const CompassOptions(
    updateInterval: Duration(milliseconds: 100),
    smoothing: CompassSmoothing.circularAverage(window: 10),
  ),
);
```

### Declination without a stream

```dart
final declination = MagneticDeclination.at(latitude: 47.6, longitude: -122.3);
final trueHeading = Angles.normalize360(magneticHeading + declination);
```

### Theming `CompassView`

```dart
CompassView(
  heading: 42,
  targetBearing: 118, // Qibla, a destination...
  theme: const CompassTheme.dark().copyWith(tickCount: 120, showDegreeLabels: true),
  needleBuilder: (context, radius, theme) =>
      Icon(Icons.navigation, size: radius, color: theme.needleColor),
  centerBuilder: (context, heading) => Text('${heading.round()}'),
);
```

## API

### `TrueCompass`

| Member | Description |
|---|---|
| `TrueCompass({options})` | Creates a compass. Nothing runs until a stream is listened to. |
| `headings` | `Stream<CompassHeading>`, at most one per `updateInterval`. |
| `accuracyChanges` | `Stream<CompassAccuracy>`, emits on changes. |
| `calibrationNeeded` | `Stream<bool>`, emits when the need for calibration changes. |
| `latest` | Last emitted heading. |
| `checkAvailability()` | `Future<CompassAvailability>`. |
| `requestPermission()` | Prompts where the platform requires it (iOS Safari). Call from a user gesture. |
| `setLocation(location)` | Sets or clears the location used for true north, also while streaming. |
| `dispose()` | Stops sensors and closes streams. |

### `CompassOptions`

| Option | Default | Description |
|---|---|---|
| `updateInterval` | 50 ms | Minimum time between headings; `Duration.zero` = every sample. |
| `smoothing` | low-pass, alpha 0.25 | `CompassSmoothing.none()`, `.lowPass(alpha:)`, `.circularAverage(window:)`. |
| `compensateScreenOrientation` | `true` | Heading follows the screen in landscape. |
| `location` | `null` | `CompassLocation(latitude, longitude, altitudeMeters)` for true north. |

### `CompassHeading`

`magneticHeading`, `trueHeading?`, `declination?`, `bestHeading`, `accuracy`, `needsCalibration`, `errorDegrees?`, `timestamp`, `headingFor(trueNorth:)`.

### `CompassView`

| Parameter | Description |
|---|---|
| `heading` / `CompassView.stream(stream:)` | Fixed value or a stream of `CompassHeading`. |
| `size` | Side length; defaults to the available space. |
| `theme` | `CompassTheme` (light, `.dark()`, `.fromColorScheme`, `copyWith`). Colors, ring width, tick count, labels, shadow, needle. |
| `trueNorth` | Use `trueHeading` when available (default `true`). |
| `animationDuration` | Rotation animation; `Duration.zero` disables. |
| `targetBearing` | Marks a bearing on the dial. |
| `needleBuilder`, `centerBuilder`, `overlayBuilder` | Replace or add content. |
| `semanticLabel` | Accessibility label (heading is appended). |

### Utilities

`MagneticDeclination.at/field`, `Angles` (`normalize360`, `shortestDelta`, `circularMean`, `cardinal8/16`), `OrientationMath` (rotation matrix and Euler angle to heading).

## How it works

Native code only forwards raw sensor data (Android rotation matrix, iOS CoreLocation heading, web orientation angles). The heading math, screen rotation, tilt blending, smoothing, throttling and declination all run in Dart, so they are unit tested without a device and behave the same on every platform.

True heading is `magnetic heading + declination`. The WMM2025 coefficients (NOAA/NCEI, public domain) are valid until 2030-01-01; after that `MagneticDeclination.field(...).isWithinValidity` is `false` and values degrade gradually. Accuracy is about 0.5 degrees for most places and worse near the magnetic poles.

## Migration: coming from `flutter_compass`

| `flutter_compass` | `true_compass` |
|---|---|
| `FlutterCompass.events` | `TrueCompass().headings` |
| `event.heading` (may be negative or null) | `heading.magneticHeading` (always `[0, 360)`) |
| `event.headingForCameraMode` | `heading.magneticHeading` (tilt is blended automatically) |
| `event.accuracy` | `heading.accuracy` (`CompassAccuracy`) and `calibrationNeeded` |
| (none) | `heading.trueHeading` with `CompassOptions(location: ...)` |

```dart
// Before
FlutterCompass.events?.listen((e) => update(e.heading));
// After
final compass = TrueCompass();
compass.headings.listen((h) => update(h.magneticHeading));
```

## FAQ

**Why is `trueHeading` null?** You did not give a location. Pass `CompassOptions(location: ...)` or call `setLocation`. The package deliberately does not read location itself.

**Do I need a precise location?** No. Declination changes by a fraction of a degree over tens of kilometers.

**The needle drifts or is off by 10 to 30 degrees.** Magnetometers are disturbed by metal, magnets and phone cases. Listen to `calibrationNeeded` and ask the user to wave the phone in a figure of eight.

**Does it work in a simulator?** Emulators have no magnetometer. `checkAvailability()` returns `noSensor` and the stream reports an error; feed `CompassView` your own `Stream<CompassHeading>` (the example has a simulator).

**Why does iOS Safari ask for permission?** Safari gates `DeviceOrientationEvent` behind a prompt that must start from a user gesture.

## Contributing

Issues and pull requests are welcome at https://github.com/Rishav1995-roy/true_compass. Run `flutter analyze` and `flutter test` before opening a PR. The demo GIF is regenerated with `tool/make_demo.sh` (see `tool/generate_demo_test.dart`).

## Credits and license

WMM2025 model and coefficients: NOAA National Centers for Environmental Information and the British Geological Survey (public domain). The spherical harmonic evaluation is written from the model's published description and checked against NOAA's test values.

MIT, see [LICENSE](LICENSE).
