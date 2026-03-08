import 'package:swim_apps_shared/objects/stroke.dart';

enum TrainingResultSourceType { manual, voice }

class TrainingResultVoiceCapture {
  const TrainingResultVoiceCapture({
    required this.transcript,
    required this.model,
    required this.capturedAt,
  });

  final String transcript;
  final String model;
  final DateTime capturedAt;

  TrainingResultVoiceCapture copyWith({
    String? transcript,
    String? model,
    DateTime? capturedAt,
  }) {
    return TrainingResultVoiceCapture(
      transcript: transcript ?? this.transcript,
      model: model ?? this.model,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript,
      'model': model,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  factory TrainingResultVoiceCapture.fromJson(Map<String, dynamic> json) {
    return TrainingResultVoiceCapture(
      transcript: _asString(json['transcript']),
      model: _asString(json['model']),
      capturedAt: _asDateTime(json['capturedAt']),
    );
  }
}

class TrainingResultSet {
  final String id;
  final String clubId;
  final String swimmerId;
  final String createdByCoachId;
  final String rawTitle;
  final Stroke stroke;
  final int repetitions;
  final int distancePerRep;
  final Duration restInterval;
  final int intensity;
  final DateTime sessionDate;
  final List<TrainingResultEntry> entries;
  final String? sessionId;
  final String? sessionSetRefId;
  final TrainingResultSourceType? sourceType;
  final TrainingResultVoiceCapture? voiceCapture;

  const TrainingResultSet({
    required this.id,
    required this.clubId,
    required this.swimmerId,
    required this.createdByCoachId,
    required this.rawTitle,
    required this.stroke,
    required this.repetitions,
    required this.distancePerRep,
    required this.restInterval,
    required this.intensity,
    required this.sessionDate,
    required this.entries,
    this.sessionId,
    this.sessionSetRefId,
    this.sourceType,
    this.voiceCapture,
  });

  TrainingResultSet copyWith({
    String? id,
    String? clubId,
    String? swimmerId,
    String? createdByCoachId,
    String? rawTitle,
    Stroke? stroke,
    int? repetitions,
    int? distancePerRep,
    Duration? restInterval,
    int? intensity,
    DateTime? sessionDate,
    List<TrainingResultEntry>? entries,
    Object? sessionId = _unset,
    Object? sessionSetRefId = _unset,
    Object? sourceType = _unset,
    Object? voiceCapture = _unset,
  }) {
    return TrainingResultSet(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      swimmerId: swimmerId ?? this.swimmerId,
      createdByCoachId: createdByCoachId ?? this.createdByCoachId,
      rawTitle: rawTitle ?? this.rawTitle,
      stroke: stroke ?? this.stroke,
      repetitions: repetitions ?? this.repetitions,
      distancePerRep: distancePerRep ?? this.distancePerRep,
      restInterval: restInterval ?? this.restInterval,
      intensity: intensity ?? this.intensity,
      sessionDate: sessionDate ?? this.sessionDate,
      entries: entries ?? this.entries,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      sessionSetRefId: identical(sessionSetRefId, _unset)
          ? this.sessionSetRefId
          : sessionSetRefId as String?,
      sourceType: identical(sourceType, _unset)
          ? this.sourceType
          : sourceType as TrainingResultSourceType?,
      voiceCapture: identical(voiceCapture, _unset)
          ? this.voiceCapture
          : voiceCapture as TrainingResultVoiceCapture?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clubId': clubId,
      'swimmerId': swimmerId,
      'createdByCoachId': createdByCoachId,
      'rawTitle': rawTitle,
      'stroke': stroke.name,
      'repetitions': repetitions,
      'distancePerRep': distancePerRep,
      'restIntervalMs': restInterval.inMilliseconds,
      'intensity': intensity,
      'sessionDate': sessionDate.toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
      'sessionId': sessionId,
      'sessionSetRefId': sessionSetRefId,
      'sourceType': sourceType?.name,
      'voiceCapture': voiceCapture?.toJson(),
    };
  }

  factory TrainingResultSet.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return TrainingResultSet(
      id: _asString(json['id']),
      clubId: _asString(json['clubId']),
      swimmerId: _asString(json['swimmerId']),
      createdByCoachId: _asString(json['createdByCoachId']),
      rawTitle: _asString(json['rawTitle']),
      stroke: Stroke.fromString(json['stroke'] as String?) ?? Stroke.unknown,
      repetitions: _asInt(json['repetitions'], fallback: 1).clamp(1, 9999),
      distancePerRep: _asInt(
        json['distancePerRep'],
        fallback: 0,
      ).clamp(0, 9999),
      restInterval: Duration(
        milliseconds: _asInt(
          json['restIntervalMs'],
          fallback: 0,
        ).clamp(0, 24 * 60 * 60 * 1000),
      ),
      intensity: _asInt(json['intensity'], fallback: 0).clamp(0, 10),
      sessionDate: _asDateTime(json['sessionDate']),
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) => TrainingResultEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList(growable: false)
          : const <TrainingResultEntry>[],
      sessionId: _optionalString(json['sessionId']),
      sessionSetRefId: _optionalString(json['sessionSetRefId']),
      sourceType: _parseSourceType(json['sourceType']),
      voiceCapture: _parseVoiceCapture(json['voiceCapture']),
    );
  }
}

class TrainingResultEntry {
  final int repIndex;
  final Duration resultTime;
  final String? note;

  const TrainingResultEntry({
    required this.repIndex,
    required this.resultTime,
    this.note,
  });

  TrainingResultEntry copyWith({
    int? repIndex,
    Duration? resultTime,
    String? note,
  }) {
    return TrainingResultEntry(
      repIndex: repIndex ?? this.repIndex,
      resultTime: resultTime ?? this.resultTime,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'repIndex': repIndex,
      'resultTimeMs': resultTime.inMilliseconds,
      'note': note,
    };
  }

  factory TrainingResultEntry.fromJson(Map<String, dynamic> json) {
    return TrainingResultEntry(
      repIndex: _asInt(json['repIndex'], fallback: 0).clamp(0, 9999),
      resultTime: Duration(
        milliseconds: _asInt(
          json['resultTimeMs'],
          fallback: 0,
        ).clamp(0, 24 * 60 * 60 * 1000),
      ),
      note: json['note'] is String ? json['note'] as String : null,
    );
  }
}

int _asInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}

String _asString(dynamic value) {
  if (value is String) return value;
  return '';
}

DateTime _asDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String? _optionalString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

TrainingResultSourceType? _parseSourceType(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'manual':
      return TrainingResultSourceType.manual;
    case 'voice':
      return TrainingResultSourceType.voice;
    default:
      return null;
  }
}

TrainingResultVoiceCapture? _parseVoiceCapture(dynamic value) {
  if (value is! Map) return null;
  return TrainingResultVoiceCapture.fromJson(Map<String, dynamic>.from(value));
}

class _Unset {
  const _Unset();
}

const _unset = _Unset();
