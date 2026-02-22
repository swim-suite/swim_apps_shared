import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/stroke.dart';
import 'package:swim_apps_shared/training_results/training_result_parser.dart';

void main() {
  group('parseTrainingSet', () {
    test('parses canonical set metadata', () {
      final parsed = parseTrainingSet('4x25 br @1:00 i7');

      expect(parsed.rawTitle, '4x25 br @1:00 i7');
      expect(parsed.repetitions, 4);
      expect(parsed.distancePerRep, 25);
      expect(parsed.stroke, Stroke.breaststroke);
      expect(parsed.restInterval, const Duration(minutes: 1));
      expect(parsed.intensity, 7);
      expect(parsed.hasSetStructure, isTrue);
      expect(parsed.warnings, isEmpty);
    });

    test('handles single repetition with missing optional fields', () {
      final parsed = parseTrainingSet('1x50');

      expect(parsed.repetitions, 1);
      expect(parsed.distancePerRep, 50);
      expect(parsed.stroke, Stroke.unknown);
      expect(parsed.restInterval, isNull);
      expect(parsed.intensity, isNull);
      expect(parsed.hasSetStructure, isTrue);
    });

    test('parses compact stroke tokens without spaces', () {
      final parsed = parseTrainingSet('4x25fr@1:00i6');

      expect(parsed.repetitions, 4);
      expect(parsed.distancePerRep, 25);
      expect(parsed.stroke, Stroke.freestyle);
      expect(parsed.intensity, 6);
      expect(parsed.restInterval, const Duration(minutes: 1));
    });

    test('falls back gracefully for kick/choice style text', () {
      final parsed = parseTrainingSet('6x50 kick choice @55');

      expect(parsed.repetitions, 6);
      expect(parsed.distancePerRep, 50);
      expect(parsed.stroke, Stroke.unknown);
      expect(parsed.restInterval, const Duration(seconds: 55));
      expect(parsed.warnings, isNotEmpty);
    });

    test('returns defaults for malformed input', () {
      final parsed = parseTrainingSet('non-standard input');

      expect(parsed.repetitions, 1);
      expect(parsed.distancePerRep, 0);
      expect(parsed.stroke, Stroke.unknown);
      expect(parsed.hasSetStructure, isFalse);
      expect(parsed.warnings, isNotEmpty);
    });
  });
}
