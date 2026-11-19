## 0.0.2

Keeps the full pub.dev static analysis score on Flutter 3.50 and later, which deprecates `package:flutter/material.dart`. No API or behavior changes.

## 0.0.1

Initial release.

* `TrueCompass`: heading stream with magnetic and true north, accuracy and calibration streams, configurable update interval, smoothing and screen-rotation compensation.
* `MagneticDeclination`: World Magnetic Model 2025 (WMM2025) in pure Dart, verified against NOAA's published test values.
* `CompassView`: themeable dial with builders, target marker and shortest-arc animation.
* Android (rotation vector sensor, Kotlin, AGP 8 and 9 compatible, no androidx dependency), iOS (CoreLocation heading, Swift Package Manager and CocoaPods) and web (`DeviceOrientationEvent`, iOS Safari permission flow).
