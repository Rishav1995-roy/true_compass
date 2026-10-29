# true_compass example

Run on a real device (emulators have no magnetometer; use the **Simulate**
switch there):

```sh
flutter run            # Android / iOS device
flutter run -d chrome  # web; sensors need HTTPS on a phone (see the package README)
```

Screens: **Live** (real or simulated heading, true north, calibration
banner, smoothing and update rate), **Customize** (themes, builders, target
marker) and **Declination** (offline WMM2025 values for world cities).
