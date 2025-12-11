import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/swim_session/events/checkpoint.dart';

void main() {
  group('CheckPoint.expectedDistance', () {
    // helpers
    double call(
      CheckPoint cp, {
      required int poolLength,
      required int raceDistance,
    }) {
      return cp.expectedDistance(
        poolLengthMeters: poolLength,
        raceDistanceMeters: raceDistance,
      );
    }

    // ────────────────────────────────────────────────────────────────
    // COMMON VALUES
    // ────────────────────────────────────────────────────────────────

    test('start returns 0', () {
      expect(call(CheckPoint.start, poolLength: 25, raceDistance: 50), 0);
      expect(call(CheckPoint.start, poolLength: 50, raceDistance: 100), 0);
    });

    test('offTheBlock & breakOut return 5', () {
      expect(call(CheckPoint.offTheBlock, poolLength: 25, raceDistance: 50), 5);
      expect(call(CheckPoint.breakOut, poolLength: 50, raceDistance: 200), 5);
    });

    test('fifteenMeterMark returns 15', () {
      expect(
          call(CheckPoint.fifteenMeterMark, poolLength: 25, raceDistance: 100),
          15);
    });

    test('thirtyFiveMeterMark returns 35', () {
      expect(
          call(CheckPoint.thirtyFiveMeterMark,
              poolLength: 25, raceDistance: 200),
          35);
    });

    test('finish returns raceDistance', () {
      expect(call(CheckPoint.finish, poolLength: 25, raceDistance: 50), 50);
      expect(call(CheckPoint.finish, poolLength: 50, raceDistance: 200), 200);
    });

    // ────────────────────────────────────────────────────────────────
    // TURN LOGIC
    // ────────────────────────────────────────────────────────────────

    group('turn logic', () {
      test('50m SHORT COURSE (25m pool) → turn = 25', () {
        expect(call(CheckPoint.turn, poolLength: 25, raceDistance: 50), 25);
      });

      test('50m LONG COURSE (50m pool) → turn DOES NOT EXIST → returns 0', () {
        // as per your refactor
        expect(call(CheckPoint.turn, poolLength: 50, raceDistance: 50), 0);
      });

      test('100m SHORT COURSE (25m pool) → turn = 25', () {
        expect(call(CheckPoint.turn, poolLength: 25, raceDistance: 100), 25);
      });

      test('100m LONG COURSE (50m pool) → turn = 50', () {
        expect(call(CheckPoint.turn, poolLength: 50, raceDistance: 100), 50);
      });

      test('200m SHORT COURSE (25m pool) → turn = 25', () {
        expect(call(CheckPoint.turn, poolLength: 25, raceDistance: 200), 25);
      });

      test('200m LONG COURSE (50m pool) → turn = 50', () {
        expect(call(CheckPoint.turn, poolLength: 50, raceDistance: 200), 50);
      });
    });
  });
}
