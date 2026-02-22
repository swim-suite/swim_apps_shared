String normalizeResultTag(String value) {
  final lower = value.toLowerCase();
  return lower.replaceAll(RegExp(r'[^a-z0-9@:x]'), '');
}

bool isSimilarTag(String a, String b) {
  final normalizedA = normalizeResultTag(a);
  final normalizedB = normalizeResultTag(b);

  if (normalizedA.isEmpty || normalizedB.isEmpty) {
    return false;
  }
  if (normalizedA == normalizedB) {
    return true;
  }

  final collapsedA = normalizedA.replaceAll(RegExp(r'[@:]'), '');
  final collapsedB = normalizedB.replaceAll(RegExp(r'[@:]'), '');
  if (collapsedA == collapsedB) {
    return true;
  }

  final distance = _levenshteinDistance(normalizedA, normalizedB);
  final longestLength = normalizedA.length > normalizedB.length
      ? normalizedA.length
      : normalizedB.length;
  if (longestLength == 0) return false;

  final normalizedDistance = distance / longestLength;
  return normalizedDistance <= 0.1;
}

int _levenshteinDistance(String left, String right) {
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  final previous = List<int>.generate(right.length + 1, (i) => i);
  final current = List<int>.filled(right.length + 1, 0);

  for (var i = 0; i < left.length; i++) {
    current[0] = i + 1;

    for (var j = 0; j < right.length; j++) {
      final cost = left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1;
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      final substitution = previous[j] + cost;
      current[j + 1] = _min3(insertion, deletion, substitution);
    }

    for (var j = 0; j <= right.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous[right.length];
}

int _min3(int a, int b, int c) {
  final minAB = a < b ? a : b;
  return minAB < c ? minAB : c;
}
