import 'package:swim_apps_shared/objects/stroke.dart';
import 'package:swim_apps_shared/training_results/training_result_metadata.dart';

final RegExp _setPattern = RegExp(r'(\d+)\s*[xX]\s*(\d+)');
final RegExp _restPattern = RegExp(
  r'(?:@|rest)\s*([0-9]{1,2}(?::[0-9]{1,2})?)',
  caseSensitive: false,
);
final RegExp _intensityPattern = RegExp(
  r'(?:^|[^a-z])i\s*(\d{1,2})(?=$|[^a-z0-9])|intensity\s*(\d{1,2})',
  caseSensitive: false,
);

TrainingResultMetadata parseTrainingSet(String rawText) {
  final trimmed = rawText.trim();
  if (trimmed.isEmpty) {
    return TrainingResultMetadata.empty(
      rawText,
    ).copyWith(warnings: const <String>['No text selected.']);
  }

  final warnings = <String>[];
  final normalized = trimmed.toLowerCase();

  var repetitions = 1;
  var distancePerRep = 0;
  var hasSetStructure = false;
  final setMatch = _setPattern.firstMatch(normalized);
  if (setMatch != null) {
    repetitions = int.tryParse(setMatch.group(1) ?? '') ?? 1;
    distancePerRep = int.tryParse(setMatch.group(2) ?? '') ?? 0;
    hasSetStructure = true;
  } else {
    warnings.add('Could not detect a repetition-distance pattern (e.g. 4x25).');
  }

  final stroke = _parseStroke(normalized);
  if (stroke == Stroke.unknown && _containsKickOrChoice(normalized)) {
    warnings.add('Kick/choice set detected. Stroke set to unknown.');
  }

  Duration? restInterval;
  final restMatch = _restPattern.firstMatch(normalized);
  if (restMatch != null) {
    restInterval = _parseRestInterval(restMatch.group(1) ?? '');
    if (restInterval == null) {
      warnings.add('Rest interval could not be parsed.');
    }
  }

  int? intensity;
  final intensityMatch = _intensityPattern.firstMatch(normalized);
  if (intensityMatch != null) {
    final value = intensityMatch.group(1) ?? intensityMatch.group(2) ?? '';
    intensity = int.tryParse(value);
    if (intensity != null) {
      intensity = intensity.clamp(0, 10);
    }
  }

  return TrainingResultMetadata(
    rawTitle: trimmed,
    stroke: stroke,
    repetitions: repetitions.clamp(1, 9999),
    distancePerRep: distancePerRep.clamp(0, 9999),
    restInterval: restInterval,
    intensity: intensity,
    hasSetStructure: hasSetStructure,
    warnings: warnings,
  );
}

Duration? _parseRestInterval(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.contains(':')) {
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    if (minutes < 0 || seconds < 0 || seconds >= 60) return null;
    return Duration(minutes: minutes, seconds: seconds);
  }

  final seconds = int.tryParse(trimmed);
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}

Stroke _parseStroke(String normalizedText) {
  if (_matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(freestyle|free|fr)([^a-z]|$)'),
  ])) {
    return Stroke.freestyle;
  }
  if (_matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(backstroke|back|bk|ba)([^a-z]|$)'),
  ])) {
    return Stroke.backstroke;
  }
  if (_matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(breaststroke|breast|br)([^a-z]|$)'),
  ])) {
    return Stroke.breaststroke;
  }
  if (_matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(butterfly|fly|bf|bu)([^a-z]|$)'),
  ])) {
    return Stroke.butterfly;
  }
  if (_matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(medley|im|i\.m)([^a-z]|$)'),
  ])) {
    return Stroke.medley;
  }
  return Stroke.unknown;
}

bool _containsKickOrChoice(String normalizedText) {
  return _matchesAny(normalizedText, <RegExp>[
    RegExp(r'(^|[^a-z])(kick|choice|ch)([^a-z]|$)'),
  ]);
}

bool _matchesAny(String value, List<RegExp> patterns) {
  for (final pattern in patterns) {
    if (pattern.hasMatch(value)) {
      return true;
    }
  }
  return false;
}
