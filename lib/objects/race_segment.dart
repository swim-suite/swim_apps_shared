import 'package:swim_apps_shared/swim_session/events/checkpoint.dart';

//@immutable
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
  double? strokeFreq; // strokes/min
  final double? strokeLength; // m/stroke
  final double? strokeIndex; // m^2/s

  // Breakout timing
  final Duration? breakoutTime;

  RaceSegment({
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

  static num? _parseNum(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    if (raw is Duration) return raw.inMilliseconds;

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      final direct = num.tryParse(trimmed);
      if (direct != null) return direct;

      final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(trimmed);
      if (match == null) return null;
      return num.tryParse(match.group(0)!);
    }

    if (raw is Map) {
      const preferredKeys = [
        'value',
        'distance',
        'meters',
        'meter',
        'm',
        'count',
        'total',
        'milliseconds',
        'millis',
        'ms',
        'time',
      ];

      for (final key in preferredKeys) {
        final parsed = _parseNum(raw[key]);
        if (parsed != null) return parsed;
      }

      for (final value in raw.values) {
        final parsed = _parseNum(value);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static double _parseDouble(dynamic raw, {double fallback = 0.0}) =>
      _parseNum(raw)?.toDouble() ?? fallback;

  static double? _parseNullableDouble(dynamic raw) =>
      _parseNum(raw)?.toDouble();

  static int? _parseInt(dynamic raw) => _parseNum(raw)?.toInt();

  static CheckPoint _parseCheckPoint(dynamic raw) {
    String? checkPointName;

    if (raw is String) {
      checkPointName = raw;
    } else if (raw is Map) {
      const keys = ['checkPoint', 'name', 'value', 'type'];
      for (final key in keys) {
        final candidate = raw[key];
        if (candidate is String && candidate.isNotEmpty) {
          checkPointName = candidate;
          break;
        }
      }
    }

    if (checkPointName == null || checkPointName.isEmpty) {
      return CheckPoint.finish;
    }

    for (final cp in CheckPoint.values) {
      if (cp.name == checkPointName) return cp;
    }

    final lower = checkPointName.toLowerCase();
    for (final cp in CheckPoint.values) {
      if (lower.contains(cp.name.toLowerCase())) return cp;
    }

    return CheckPoint.finish;
  }

  factory RaceSegment.fromMap(Map<String, dynamic> map) {
    final checkPoint = _parseCheckPoint(map['checkPoint']);
    final strokeFreqValue = map['strokeFreq'] ?? map['strokeFrequency'];
    final strokeLengthValue = map['strokeLength'] ?? map['strokeLengthMeters'];
    final segmentDistanceValue =
        map['segmentDistance'] ?? map['distanceMeters'];
    final accumulatedDistanceValue =
        map['accumulatedDistance'] ?? segmentDistanceValue;

    return RaceSegment(
      sequence: _parseInt(map['sequence']) ?? 0,
      checkPoint: checkPoint,
      accumulatedDistance: _parseDouble(accumulatedDistanceValue),
      segmentDistance: _parseDouble(segmentDistanceValue),
      underwaterDistance: map['underwaterDistance'] == null
          ? null
          : _parseDouble(map['underwaterDistance']),
      splitTimeMillis: _parseInt(map['splitTimeMillis']) ?? 0,
      totalTimeMillis: _parseInt(map['totalTimeMillis']) ?? 0,
      strokes: _parseInt(map['strokes']),
      dolphinKicks: _parseInt(map['dolphinKicks']),
      breaths: _parseInt(map['breaths']),
      avgSpeed: _parseNullableDouble(map['avgSpeed']),
      strokeFreq: _parseNullableDouble(strokeFreqValue),
      strokeLength: _parseNullableDouble(strokeLengthValue),
      strokeIndex: _parseNullableDouble(map['strokeIndex']),
      breakoutTime: map['breakoutTime'] == null
          ? null
          : Duration(milliseconds: _parseInt(map['breakoutTime']) ?? 0),
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
