import 'package:swim_apps_shared/objects/stroke.dart';

class TrainingResultMetadata {
  final String rawTitle;
  final Stroke stroke;
  final int repetitions;
  final int distancePerRep;
  final Duration? restInterval;
  final int? intensity;
  final bool hasSetStructure;
  final List<String> warnings;

  const TrainingResultMetadata({
    required this.rawTitle,
    required this.stroke,
    required this.repetitions,
    required this.distancePerRep,
    required this.restInterval,
    required this.intensity,
    required this.hasSetStructure,
    required this.warnings,
  });

  factory TrainingResultMetadata.empty(String rawTitle) {
    return TrainingResultMetadata(
      rawTitle: rawTitle.trim(),
      stroke: Stroke.unknown,
      repetitions: 1,
      distancePerRep: 0,
      restInterval: null,
      intensity: null,
      hasSetStructure: false,
      warnings: const <String>[],
    );
  }

  TrainingResultMetadata copyWith({
    String? rawTitle,
    Stroke? stroke,
    int? repetitions,
    int? distancePerRep,
    Duration? restInterval,
    bool clearRestInterval = false,
    int? intensity,
    bool clearIntensity = false,
    bool? hasSetStructure,
    List<String>? warnings,
  }) {
    return TrainingResultMetadata(
      rawTitle: rawTitle ?? this.rawTitle,
      stroke: stroke ?? this.stroke,
      repetitions: repetitions ?? this.repetitions,
      distancePerRep: distancePerRep ?? this.distancePerRep,
      restInterval: clearRestInterval
          ? null
          : restInterval ?? this.restInterval,
      intensity: clearIntensity ? null : intensity ?? this.intensity,
      hasSetStructure: hasSetStructure ?? this.hasSetStructure,
      warnings: warnings ?? this.warnings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawTitle': rawTitle,
      'stroke': stroke.name,
      'repetitions': repetitions,
      'distancePerRep': distancePerRep,
      'restIntervalMs': restInterval?.inMilliseconds,
      'intensity': intensity,
      'hasSetStructure': hasSetStructure,
      'warnings': warnings,
    };
  }

  factory TrainingResultMetadata.fromJson(Map<String, dynamic> json) {
    return TrainingResultMetadata(
      rawTitle: json['rawTitle'] is String ? json['rawTitle'] as String : '',
      stroke: Stroke.fromString(json['stroke'] as String?) ?? Stroke.unknown,
      repetitions: _asInt(json['repetitions'], fallback: 1).clamp(1, 9999),
      distancePerRep: _asInt(
        json['distancePerRep'],
        fallback: 0,
      ).clamp(0, 9999),
      restInterval: json['restIntervalMs'] is num
          ? Duration(milliseconds: (json['restIntervalMs'] as num).toInt())
          : null,
      intensity: json['intensity'] is num
          ? (json['intensity'] as num).toInt().clamp(0, 10)
          : null,
      hasSetStructure: json['hasSetStructure'] == true,
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).whereType<String>().toList()
          : const <String>[],
    );
  }
}

int _asInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}
