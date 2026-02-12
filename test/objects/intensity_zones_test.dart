import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/intensity_zones.dart';

void main() {
  group('IntensityZone.intensityColor', () {
    test('returns expected color for each zone', () {
      final expected = <IntensityZone, Color>{
        IntensityZone.max: Colors.red,
        IntensityZone.sp3: Colors.redAccent,
        IntensityZone.sp2: Colors.purple,
        IntensityZone.sp1: Colors.purpleAccent,
        IntensityZone.i4: Colors.purpleAccent.withBlue(10),
        IntensityZone.i3: Colors.cyanAccent,
        IntensityZone.i2: Colors.cyan,
        IntensityZone.i1: Colors.blue,
        IntensityZone.racePace: Colors.orange,
      };

      for (final entry in expected.entries) {
        expect(
          entry.key.intensityColor(),
          entry.value,
          reason: 'Color mismatch for ${entry.key}',
        );
      }
    });
  });

  group('IntensityZone.hrMaxPercentRange', () {
    test('returns expected HR max percent ranges', () {
      final expected = <IntensityZone, (int, int)>{
        IntensityZone.i1: (50, 65),
        IntensityZone.i2: (65, 75),
        IntensityZone.i3: (75, 85),
        IntensityZone.i4: (85, 95),
        IntensityZone.sp1: (90, 98),
        IntensityZone.sp2: (92, 100),
        IntensityZone.sp3: (95, 100),
        IntensityZone.max: (98, 100),
        IntensityZone.racePace: (85, 100),
      };

      for (final entry in expected.entries) {
        expect(
          entry.key.hrMaxPercentRange,
          entry.value,
          reason: 'HR range mismatch for ${entry.key}',
        );
      }
    });

    test('ranges are well-formed (min <= max, within 0..100)', () {
      for (final zone in IntensityZone.values) {
        final (minPercent, maxPercent) = zone.hrMaxPercentRange;
        expect(minPercent, inInclusiveRange(0, 100));
        expect(maxPercent, inInclusiveRange(0, 100));
        expect(minPercent <= maxPercent, isTrue, reason: 'Bad range for $zone');
      }
    });
  });

  group('IntensityZoneParsingHelper.parsingKeywords', () {
    test('includes canonical names and short strings', () {
      for (final zone in IntensityZone.values) {
        final keywords =
            zone.parsingKeywords.map((s) => s.toLowerCase()).toSet();
        expect(keywords.contains(zone.name.toLowerCase()), isTrue);
        expect(keywords.contains(zone.toShortString().toLowerCase()), isTrue);
      }
    });

    test('race pace includes common aliases', () {
      final keywords = IntensityZone.racePace.parsingKeywords
          .map((s) => s.toLowerCase())
          .toSet();
      expect(keywords.contains('race pace'), isTrue);
      expect(keywords.contains('rp'), isTrue);
    });

    test('max does not include race pace aliases', () {
      final keywords =
          IntensityZone.max.parsingKeywords.map((s) => s.toLowerCase()).toSet();
      expect(keywords.contains('race pace'), isFalse);
      expect(keywords.contains('rp'), isFalse);
    });
  });

  group('IntensitySorting.sortOrder', () {
    test('matches expected ordering', () {
      final expected = <IntensityZone, int>{
        IntensityZone.i1: 1,
        IntensityZone.i2: 2,
        IntensityZone.i3: 3,
        IntensityZone.i4: 4,
        IntensityZone.racePace: 5,
        IntensityZone.sp1: 6,
        IntensityZone.sp2: 7,
        IntensityZone.sp3: 8,
        IntensityZone.max: 9,
      };

      for (final entry in expected.entries) {
        expect(entry.key.sortOrder, entry.value);
      }
    });

    test('sortOrder values are unique', () {
      final values = IntensityZone.values.map((z) => z.sortOrder).toList();
      expect(values.toSet().length, values.length);
    });
  });

  group('Enum safety checks', () {
    test('no intensity zones are missing tests', () {
      expect(
        IntensityZone.values.length,
        9,
        reason:
            'New IntensityZone added – update intensityColor, HR ranges, parsing, sorting, and tests',
      );
    });
  });
}
