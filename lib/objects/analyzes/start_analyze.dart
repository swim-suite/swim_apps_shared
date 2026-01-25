import 'package:swim_apps_shared/objects/analyzes/analyze_base.dart';

class StartAnalyze with AnalyzableBase {
  String title;
  final DateTime date;

  final Map<String, int> markedTimestamps;
  final double startDistance;
  final double startHeight;

  final Map<String, double>? jumpData;
  String? aiInterpretation;

  DateTime? updatedAt;

  StartAnalyze({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    DateTime? createdAt,
    this.updatedAt,
    required this.title,
    required this.date,
    required this.markedTimestamps,
    required this.startDistance,
    required this.startHeight,
    this.jumpData,
    this.aiInterpretation,
  }) {
    this.id = id;
    this.coachId = coachId;
    this.swimmerId = swimmerId;
    this.swimmerName = swimmerName;
    this.createdAt = createdAt;
  }

  // ---------------------------------------------------------------------------
  // COPYWITH
  // ---------------------------------------------------------------------------
  StartAnalyze copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? swimmerId,
    String? swimmerName,
    String? coachId,
    String? clubId,
    Map<String, int>? markedTimestamps,
    double? startDistance,
    double? startHeight,
    Map<String, double>? jumpData,
    String? aiInterpretation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StartAnalyze(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      swimmerId: swimmerId ?? this.swimmerId,
      swimmerName: swimmerName ?? this.swimmerName,
      coachId: coachId ?? this.coachId,
      markedTimestamps: markedTimestamps ?? this.markedTimestamps,
      startDistance: startDistance ?? this.startDistance,
      startHeight: startHeight ?? this.startHeight,
      jumpData: jumpData ?? this.jumpData,
      aiInterpretation: aiInterpretation ?? this.aiInterpretation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // FROM MAP
  // ---------------------------------------------------------------------------
  factory StartAnalyze.fromMap(Map<String, dynamic> map, String docId) {
    final analyze = StartAnalyze(
      id: docId,
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      markedTimestamps: Map<String, int>.from(map['markedTimestamps'] as Map),
      startDistance: (map['startDistance'] as num).toDouble(),
      startHeight: (map['startHeight'] as num).toDouble(),
      aiInterpretation: map['aiInterpretation'],
      jumpData: map['jumpData'] != null
          ? Map<String, double>.from(map['jumpData'] as Map)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );

    analyze.loadAnalyzableBase(map, docId);
    return analyze;
  }

  // ---------------------------------------------------------------------------
  // TO MAP
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      ...analyzableBaseToJson(),
      'title': title,
      'date': date.toIso8601String(),
      'clubId': clubId,
      'markedTimestamps': markedTimestamps,
      'startDistance': startDistance,
      'startHeight': startHeight,
      'aiInterpretation': aiInterpretation,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (jumpData != null) 'jumpData': jumpData,
    };
  }
}
