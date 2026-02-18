import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/stroke.dart';
import 'package:swim_apps_shared/objects/user/swimmer.dart';

void main() {
  group('StrokeResolution', () {
    test('resolveForSwimmer returns same stroke if not bestStroke', () {
      final swimmer = Swimmer(
        id: 's1',
        name: 'Swimmer',
        email: 's1@example.com',
        primaryStroke: Stroke.backstroke,
      );

      expect(Stroke.freestyle.resolveForSwimmer(swimmer), Stroke.freestyle);
    });

    test('bestStroke resolves to swimmer primaryStroke', () {
      final swimmer = Swimmer(
        id: 's1',
        name: 'Swimmer',
        email: 's1@example.com',
        primaryStroke: Stroke.butterfly,
      );

      expect(Stroke.bestStroke.resolveForSwimmer(swimmer), Stroke.butterfly);
    });

    test(
      'bestStroke falls back to freestyle if swimmer has no primaryStroke',
      () {
        final swimmer = Swimmer(
          id: 's1',
          name: 'Swimmer',
          email: 's1@example.com',
          primaryStroke: null,
        );

        expect(Stroke.bestStroke.resolveForSwimmer(swimmer), Stroke.freestyle);
      },
    );

    test('bestStroke displayName is correct', () {
      expect(Stroke.bestStroke.displayName, 'Best stroke');
    });
  });
}
