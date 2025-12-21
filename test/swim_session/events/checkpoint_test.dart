import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/swim_session/events/checkpoint.dart';

void main() {
  group('CheckPointDisplay.toDisplayString', () {
    test('returns correct display strings for all checkpoints', () {
      final expected = <CheckPoint, String>{
        CheckPoint.start: 'Start',
        CheckPoint.offTheBlock: 'Off the block',
        CheckPoint.waterEntry: 'Water entry',
        CheckPoint.breakout: 'Breakout',
        CheckPoint.turn: 'Turn',
        CheckPoint.finish: 'Finish',
        CheckPoint.meter5: '5 m',
        CheckPoint.meter10: '10 m',
        CheckPoint.meter15: '15 m',
        CheckPoint.meter25: '25 m',
        CheckPoint.meter35: '35 m',
      };

      for (final entry in expected.entries) {
        expect(
          entry.key.toDisplayString(),
          entry.value,
          reason: 'Display string mismatch for ${entry.key}',
        );
      }
    });
  });

  group('CheckPointDistance.expectedDistance', () {
    const pool25 = 25;
    const pool50 = 50;

    test('start has zero distance', () {
      expect(
        CheckPoint.start.expectedDistance(
          poolLengthMeters: pool25,
          raceDistanceMeters: 100,
        ),
        0.0,
      );
    });

    test('event checkpoints have neutral reporting distance of 5m', () {
      final eventCheckpoints = [
        CheckPoint.offTheBlock,
        CheckPoint.waterEntry,
        CheckPoint.breakout,
      ];

      for (final cp in eventCheckpoints) {
        expect(
          cp.expectedDistance(
            poolLengthMeters: pool25,
            raceDistanceMeters: 100,
          ),
          5.0,
          reason: 'Expected neutral distance for $cp',
        );
      }
    });

    test('distance mark checkpoints return correct distances', () {
      final expected = <CheckPoint, double>{
        CheckPoint.meter5: 5.0,
        CheckPoint.meter10: 10.0,
        CheckPoint.meter15: 15.0,
        CheckPoint.meter25: 25.0,
        CheckPoint.meter35: 35.0,
      };

      for (final entry in expected.entries) {
        expect(
          entry.key.expectedDistance(
            poolLengthMeters: pool25,
            raceDistanceMeters: 100,
          ),
          entry.value,
          reason: 'Distance mismatch for ${entry.key}',
        );
      }
    });

    test('turn distance is pool length for short course races', () {
      expect(
        CheckPoint.turn.expectedDistance(
          poolLengthMeters: pool25,
          raceDistanceMeters: 100,
        ),
        25.0,
      );
    });

    test('turn distance is zero for 50m long course race', () {
      expect(
        CheckPoint.turn.expectedDistance(
          poolLengthMeters: pool50,
          raceDistanceMeters: 50,
        ),
        0.0,
      );
    });

    test('turn distance is pool length for long course races > 50m', () {
      expect(
        CheckPoint.turn.expectedDistance(
          poolLengthMeters: pool50,
          raceDistanceMeters: 100,
        ),
        50.0,
      );
    });

    test('finish distance equals race distance', () {
      const distances = [50, 100, 200, 400];

      for (final raceDistance in distances) {
        expect(
          CheckPoint.finish.expectedDistance(
            poolLengthMeters: pool25,
            raceDistanceMeters: raceDistance,
          ),
          raceDistance.toDouble(),
          reason: 'Finish distance mismatch for $raceDistance m race',
        );
      }
    });
  });

  group('Enum safety checks', () {
    test('no checkpoints are missing tests', () {
      // Ensures new enum values cause test failures if not handled
      expect(
        CheckPoint.values.length,
        11,
        reason:
            'New CheckPoint added – update tests, display strings, and distance logic',
      );
    });
  });
}
