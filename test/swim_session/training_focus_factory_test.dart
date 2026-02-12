import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/endurance_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/im_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/max_velocity.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/mixed_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/race_pace_speed_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/recovery_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/speed_focus.dart';
import 'package:swim_apps_shared/swim_session/session_focuses/technique_focus.dart';
import 'package:swim_apps_shared/swim_session/training_focus_factory.dart';

void main() {
  group('TrainingFocusTypeX', () {
    test('displayName and id are stable', () {
      expect(TrainingFocusType.endurance.displayName, 'Endurance');
      expect(TrainingFocusType.endurance.id, 'endurance');

      expect(TrainingFocusType.racePace.displayName, 'Race Pace');
      expect(TrainingFocusType.racePace.id, 'race_pace');

      expect(TrainingFocusType.sprint.displayName, 'Max Velocity Sprint');
      expect(TrainingFocusType.sprint.id, 'max_velocity_sprint');
    });
  });

  group('TrainingFocusFactory.fromType', () {
    test('returns expected concrete focus types', () {
      expect(TrainingFocusFactory.fromType(TrainingFocusType.endurance),
          isA<EnduranceFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.technique),
          isA<TechniqueFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.speed),
          isA<SpeedFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.racePace),
          isA<RacePaceSpeedFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.mixed),
          isA<MixedFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.recovery),
          isA<RecoveryFocus>());
      expect(TrainingFocusFactory.fromType(TrainingFocusType.medley),
          isA<IMFocus>());
      expect(
        TrainingFocusFactory.fromType(TrainingFocusType.sprint),
        isA<MaxVelocitySprintFocus>(),
      );
    });
  });

  group('TrainingFocusFactory.fromName', () {
    test('matches names case-insensitively and supports synonyms', () {
      expect(TrainingFocusFactory.fromName('Technique'), isA<TechniqueFocus>());
      expect(TrainingFocusFactory.fromName('Technique Focus'),
          isA<TechniqueFocus>());
      expect(TrainingFocusFactory.fromName('speed focus'), isA<SpeedFocus>());
      expect(TrainingFocusFactory.fromName('race pace'),
          isA<RacePaceSpeedFocus>());
      expect(TrainingFocusFactory.fromName('Mixed / General Purpose'),
          isA<MixedFocus>());
      expect(
          TrainingFocusFactory.fromName('individual medley'), isA<IMFocus>());
      expect(TrainingFocusFactory.fromName('max sprint'),
          isA<MaxVelocitySprintFocus>());
    });

    test('defaults to MixedFocus for unknown names', () {
      expect(
          TrainingFocusFactory.fromName('totally unknown'), isA<MixedFocus>());
    });
  });

  group('TrainingFocusFactory.typeFromName', () {
    test('matches by displayName, falls back to mixed', () {
      expect(TrainingFocusFactory.typeFromName('Race Pace'),
          TrainingFocusType.racePace);
      expect(TrainingFocusFactory.typeFromName('race pace'),
          TrainingFocusType.racePace);
      expect(TrainingFocusFactory.typeFromName('unknown'),
          TrainingFocusType.mixed);
    });
  });

  group('Enum safety checks', () {
    test('no training focus types are missing tests', () {
      expect(
        TrainingFocusType.values.length,
        8,
        reason:
            'New TrainingFocusType added – update factory mappings, naming, and tests',
      );
    });
  });
}
