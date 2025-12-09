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
    return RaceSegment(
      sequence: map['sequence'],
      checkPoint:
          CheckPoint.values.firstWhere((e) => e.name == map['checkPoint']),
      accumulatedDistance: (map['accumulatedDistance'] as num).toDouble(),
      segmentDistance: (map['segmentDistance'] as num).toDouble(),
      splitTimeMillis: map['splitTimeMillis'],
      totalTimeMillis: map['totalTimeMillis'],
      underwaterDistance: (map['underwaterDistance'] as num?)?.toDouble(),
      strokes: map['strokes'],
      dolphinKicks: map['dolphinKicks'],
      breaths: map['breaths'],
      avgSpeed: (map['avgSpeed'] as num?)?.toDouble(),
      strokeFreq: (map['strokeFreq'] as num?)?.toDouble(),
      strokeLength: (map['strokeLength'] as num?)?.toDouble(),
      strokeIndex: (map['strokeIndex'] as num?)?.toDouble(),
      breakoutTime: map['breakoutTime'] != null
          ? Duration(milliseconds: map['breakoutTime'])
          : null,
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
