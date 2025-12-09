import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/swim_session/events/checkpoint.dart';

@immutable
class RaceSegment {
  final int sequence;
  final CheckPoint checkPoint;

  // Core timing
  final int splitTimeMillis;
  final int totalTimeMillis;

  // Distance information
  final double accumulatedDistance; // effective segment distance
  final double segmentDistance; // effective segment distance
  final double? underwaterDistance; // UW distance (start/turn only)

  // Stroke metrics
  final int? strokes;
  final int? dolphinKicks;
  final int? breaths;

  // Speed & efficiency
  final double? avgSpeed; // m/s
  final double? strokeFreq; // strokes/min
  final double? strokeLength; // m/stroke
  final double? strokeIndex; // m^2/s

  // Breakout timing
  final Duration? breakoutTime;

  const RaceSegment({
    required this.sequence,
    required this.checkPoint,
    required this.accumulatedDistance,
    required this.segmentDistance,
    required this.splitTimeMillis,
    required this.totalTimeMillis,
    this.underwaterDistance,
    this.strokes,
    this.dolphinKicks,
    this.breaths,
    this.avgSpeed,
    this.strokeFreq,
    this.strokeLength,
    this.strokeIndex,
    this.breakoutTime,
  });

  // --------------------------------------------------------------------------
  // 🔥 FIRESTORE
  // --------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'checkPoint': checkPoint.name,
        'accumulatedDistance': accumulatedDistance,
        'segmentDistance': segmentDistance,
        'splitTimeMillis': splitTimeMillis,
        'totalTimeMillis': totalTimeMillis,
        'underwaterDistance': underwaterDistance,
        'strokes': strokes,
        'dolphinKicks': dolphinKicks,
        'breaths': breaths,
        'avgSpeed': avgSpeed,
        'strokeFreq': strokeFreq,
        'strokeLength': strokeLength,
        'strokeIndex': strokeIndex,
        'breakoutTime': breakoutTime?.inMilliseconds,
      };

  factory RaceSegment.fromMap(Map<String, dynamic> map) {
    // Renamed helpers (no shadowing of built-in types)
    double parseDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();

    int? parseInt(dynamic v) => v == null ? null : (v as num).toInt();

    // Safe checkpoint handling
    final String? cpName = map['checkPoint'];
    final checkPoint = CheckPoint.values.firstWhere(
      (e) => e.name == cpName,
      orElse: () => CheckPoint.finish, //TODO check
    );

    return RaceSegment(
      sequence: parseInt(map['sequence']) ?? 0,
      checkPoint: checkPoint,
      accumulatedDistance: parseDouble(map['accumulatedDistance']),
      segmentDistance: parseDouble(map['segmentDistance']),
      underwaterDistance: map['underwaterDistance'] == null
          ? null
          : parseDouble(map['underwaterDistance']),
      splitTimeMillis: parseInt(map['splitTimeMillis']) ?? 0,
      totalTimeMillis: parseInt(map['totalTimeMillis']) ?? 0,
      strokes: parseInt(map['strokes']),
      dolphinKicks: parseInt(map['dolphinKicks']),
      breaths: parseInt(map['breaths']),
      avgSpeed: map['avgSpeed'] == null ? null : parseDouble(map['avgSpeed']),
      strokeFreq:
          map['strokeFreq'] == null ? null : parseDouble(map['strokeFreq']),
      strokeLength:
          map['strokeLength'] == null ? null : parseDouble(map['strokeLength']),
      strokeIndex:
          map['strokeIndex'] == null ? null : parseDouble(map['strokeIndex']),
      breakoutTime: map['breakoutTime'] == null
          ? null
          : Duration(milliseconds: parseInt(map['breakoutTime']) ?? 0),
    );
  }

  // --------------------------------------------------------------------------
  // 🤖 AI JSON (safe)
  // --------------------------------------------------------------------------
  Map<String, dynamic> toAiJson() {
    Map<String, dynamic> json = {
      "sequence": sequence,
      "checkPoint": checkPoint.name,
      'accumulatedDistance': accumulatedDistance,
      'segmentDistance': segmentDistance,
      "splitTimeMillis": splitTimeMillis,
      "totalTimeMillis": totalTimeMillis,
      "underwaterDistance": underwaterDistance,
    };

    void safe(String key, dynamic val) {
      if (val == null) return;
      if (val is num && (val.isNaN || val.isInfinite)) return;
      json[key] = val;
    }

    safe("strokes", strokes);
    safe("avgSpeed", avgSpeed);
    safe("strokeFreq", strokeFreq);
    safe("strokeLength", strokeLength);
    safe("strokeIndex", strokeIndex);

    return json;
  }
}
