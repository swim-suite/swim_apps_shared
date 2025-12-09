import 'package:swim_apps_shared/swim_session/events/checkpoint.dart';

class AnalyzedSegment {
  final int sequence;
  final CheckPoint checkPoint;
  final double distanceMeters;
  final int totalTimeMillis;
  final int splitTimeMillis;
  final int? dolphinKicks;
  final int? strokes;
  final int? breaths;
  final double? strokeFrequency;
  final double? strokeLengthMeters;
  final double? underwaterDistance;

  AnalyzedSegment({
    required this.sequence,
    required this.checkPoint,
    required this.distanceMeters,
    required this.totalTimeMillis,
    required this.splitTimeMillis,
    this.dolphinKicks,
    this.strokes,
    this.breaths,
    this.strokeFrequency,
    this.strokeLengthMeters,
      this.underwaterDistance});

  /// Converts this object into a Map for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'sequence': sequence,
      'checkPoint': checkPoint.name,
      'distanceMeters': distanceMeters,
      'totalTimeMillis': totalTimeMillis,
      'splitTimeMillis': splitTimeMillis,
      'dolphinKicks': dolphinKicks,
      'strokes': strokes,
      'breaths': breaths,
      'strokeFrequency': strokeFrequency,
      'strokeLengthMeters': strokeLengthMeters,
      'underwaterDistance': underwaterDistance
    };
  }

  Map<String, dynamic> toAiJson() {
    final Map<String, dynamic> json = {
      "sequence": sequence,
      "checkPoint": checkPoint.name,
      "distanceMeters": distanceMeters,
      "splitTimeMillis": splitTimeMillis,
      "totalTimeMillis": totalTimeMillis,
      "underwaterDistance": underwaterDistance,
    };

    // Add only SAFE values
    void addIfSafe(String key, dynamic value) {
      if (value == null) return;

      if (value is num) {
        if (value.isNaN || value.isInfinite) return;
      }

      json[key] = value;
    }

    addIfSafe("strokes", strokes);
    addIfSafe("dolphinKicks", dolphinKicks);
    addIfSafe("strokeFrequency", strokeFrequency);
    addIfSafe("strokeLengthMeters", strokeLengthMeters);

    return json;
  }

  factory AnalyzedSegment.fromMap(Map<String, dynamic> map) {
    final raw = map['checkPoint'];

    // New format: exact enum name string (fast path)
    if (raw is String && CheckPoint.values.any((e) => e.name == raw)) {
      return AnalyzedSegment(
        sequence: map['sequence'] as int,
        checkPoint: CheckPoint.values.firstWhere((e) => e.name == raw),
        distanceMeters: (map['distanceMeters'] as num).toDouble(),
        totalTimeMillis: map['totalTimeMillis'] as int,
        splitTimeMillis: map['splitTimeMillis'] as int,
        dolphinKicks: map['dolphinKicks'] as int?,
        strokes: map['strokes'] as int?,
        breaths: map['breaths'] as int?,
        strokeFrequency: (map['strokeFrequency'] as num?)?.toDouble(),
        strokeLengthMeters: (map['strokeLengthMeters'] as num?)?.toDouble(),
          underwaterDistance: map['underwaterDistance'] as double?);
    }

    // Legacy format: string may contain multiple occurrences of enum names
    final legacyCheckPoint = _CheckPointHelper.findLastMatch(raw?.toString());

    return AnalyzedSegment(
      sequence: map['sequence'] as int,
      checkPoint: legacyCheckPoint,
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      totalTimeMillis: map['totalTimeMillis'] as int,
      splitTimeMillis: map['splitTimeMillis'] as int,
      dolphinKicks: map['dolphinKicks'] as int?,
      strokes: map['strokes'] as int?,
      breaths: map['breaths'] as int?,
      strokeFrequency: (map['strokeFrequency'] as num?)?.toDouble(),
      strokeLengthMeters: (map['strokeLengthMeters'] as num?)?.toDouble(),
        underwaterDistance: map['underwaterDistance'] as double?);
  }
}

class _CheckPointHelper {
  /// Finds all enum names occurring inside a legacy string
  /// and returns the LAST occurrence.
  static CheckPoint findLastMatch(String? rawString) {
    if (rawString == null || rawString.isEmpty) {
      return CheckPoint.start; // safe fallback
    }

    final lower = rawString.toLowerCase();

    CheckPoint? lastMatch;

    for (final cp in CheckPoint.values) {
      // Look for occurrences of the enum name inside the string
      if (lower.contains(cp.name.toLowerCase())) {
        lastMatch = cp; // keep overwriting → last one wins
      }
    }

    return lastMatch ?? CheckPoint.start; // fallback
  }
}
