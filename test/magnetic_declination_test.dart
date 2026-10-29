import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:true_compass/true_compass.dart';

/// Inverse of [MagneticDeclination.decimalYear].
DateTime fromDecimalYear(double year) {
  final whole = year.floor();
  final start = DateTime.utc(whole);
  final span = DateTime.utc(whole + 1).difference(start).inMicroseconds;
  return start.add(Duration(microseconds: ((year - whole) * span).round()));
}

void main() {
  group('WMM2025 against NOAA official test values', () {
    final rows = File('test/fixtures/wmm2025_noaa_subset.txt')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split(' ').map(double.parse).toList())
        .toList();

    test('fixture has the expected number of rows', () {
      expect(rows.length, 13);
    });

    for (final row in rows) {
      final (year, altKm, lat, lon, decl, incl) =
          (row[0], row[1], row[2], row[3], row[4], row[5]);
      test('year $year, lat $lat, lon $lon, alt $altKm km', () {
        final f = MagneticDeclination.field(
          latitude: lat,
          longitude: lon,
          altitudeMeters: altKm * 1000,
          date: fromDecimalYear(year),
        );
        // NOAA publishes two decimals; stay within one unit of the last digit.
        expect(f.declination, closeTo(decl, 0.02));
        expect(f.inclination, closeTo(incl, 0.02));
        expect(f.isWithinValidity, isTrue);
      });
    }
  });

  group('declination API', () {
    test('Paris is a few degrees east, Seattle is east, Sydney is east', () {
      final date = DateTime.utc(2026, 6, 1);
      expect(
        MagneticDeclination.at(latitude: 48.85, longitude: 2.35, date: date),
        inInclusiveRange(0, 3),
      );
      expect(
        MagneticDeclination.at(latitude: 47.6, longitude: -122.3, date: date),
        inInclusiveRange(14, 17),
      );
      expect(
        MagneticDeclination.at(latitude: -33.87, longitude: 151.2, date: date),
        inInclusiveRange(11, 14),
      );
    });

    test('west declination is negative (Brazil)', () {
      expect(
        MagneticDeclination.at(
          latitude: -23.5,
          longitude: -46.6,
          date: DateTime.utc(2026),
        ),
        lessThan(-18),
      );
    });

    test('flags dates outside the model validity window', () {
      final late = MagneticDeclination.field(
        latitude: 0,
        longitude: 0,
        date: DateTime.utc(2031),
      );
      expect(late.isWithinValidity, isFalse);
      expect(late.declination.isFinite, isTrue);
    });

    test('poles do not produce NaN', () {
      for (final lat in [90.0, -90.0]) {
        final d = MagneticDeclination.at(
          latitude: lat,
          longitude: 10,
          date: DateTime.utc(2026),
        );
        expect(d.isFinite, isTrue);
      }
    });

    test('rejects non-finite input', () {
      expect(
        () => MagneticDeclination.at(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
    });

    test('decimalYear', () {
      expect(MagneticDeclination.decimalYear(DateTime.utc(2026)), 2026.0);
      expect(
        MagneticDeclination.decimalYear(DateTime.utc(2026, 7, 2, 12)),
        closeTo(2026.5, 0.002),
      );
    });
  });
}
