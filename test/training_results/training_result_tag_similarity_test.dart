import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/training_results/training_result_tag_similarity.dart';

void main() {
  group('isSimilarTag', () {
    test('treats whitespace and case changes as similar', () {
      expect(isSimilarTag('4x25 br @1:00 i7', '4x25BR@1:00I7'), isTrue);
    });

    test('treats compact format as similar', () {
      expect(isSimilarTag('4x25 br @1:00 i7', '4x25br@1:00i7'), isTrue);
    });

    test('rejects clearly different sets', () {
      expect(isSimilarTag('4x25 br @1:00 i7', '8x100 fr @2:00 i4'), isFalse);
    });

    test('returns false for empty values', () {
      expect(isSimilarTag('', ''), isFalse);
      expect(isSimilarTag('   ', '4x25 br'), isFalse);
    });
  });
}
