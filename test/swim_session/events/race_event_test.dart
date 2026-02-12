import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/pool_length.dart';
import 'package:swim_apps_shared/objects/stroke.dart';
import 'package:swim_apps_shared/swim_session/events/race_event.dart';

void main() {
  group('RaceEvent', () {
    test('asserts when withDive and relayStart are both true', () {
      expect(
        () => RaceEvent(
          stroke: Stroke.freestyle,
          distance: 100,
          poolLength: PoolLength.m25,
          withDive: true,
          relayStart: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('name uses distance and stroke description', () {
      final event = RaceEvent(
        stroke: Stroke.butterfly,
        distance: 50,
        poolLength: PoolLength.m50,
      );
      expect(event.name, '50m Butterfly');
    });

    test('short/long course flags are derived from poolLength', () {
      expect(
        RaceEvent(
                stroke: Stroke.freestyle,
                distance: 100,
                poolLength: PoolLength.m25)
            .isShortCourse,
        isTrue,
      );
      expect(
        RaceEvent(
                stroke: Stroke.freestyle,
                distance: 100,
                poolLength: PoolLength.m25)
            .isLongCourse,
        isFalse,
      );

      expect(
        RaceEvent(
                stroke: Stroke.freestyle,
                distance: 100,
                poolLength: PoolLength.m50)
            .isLongCourse,
        isTrue,
      );
      expect(
        RaceEvent(
                stroke: Stroke.freestyle,
                distance: 100,
                poolLength: PoolLength.m50)
            .isShortCourse,
        isFalse,
      );

      final yardsEvent = RaceEvent(
        stroke: Stroke.freestyle,
        distance: 100,
        poolLength: PoolLength.y25,
      );
      expect(yardsEvent.isShortCourse, isFalse);
      expect(yardsEvent.isLongCourse, isFalse);
    });
  });
}
