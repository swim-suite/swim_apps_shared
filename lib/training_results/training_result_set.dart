import 'package:swim_apps_shared/objects/stroke.dart';

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
