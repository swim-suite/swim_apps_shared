import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swim_apps_shared/objects/pool_length.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

import '../per_25.dart';
import '../race_segment.dart';
import 'analyze_base.dart';

/// Full race analysis stored in Firestore.
/// Now uses `RaceSegment` directly as the source of truth.
class RaceAnalyze with AnalyzableBase {
  String? eventName;
  String? raceName;
  String? raceAnalyzeRequestId;
  DateTime? raceDate;
  PoolLength? poolLength;
  Stroke? stroke;
  int? distance;

  /// STORED FORMAT
  List<RaceSegment> segments;

  final String? aiInterpretation;

  // Summary metrics
  int finalTime;
  double totalDistance;
  int totalStrokes;
  double averageSpeedMetersPerSecond;
  double averageStrokeFrequency;
  double averageStrokeLengthMeters;

  // Standardized metrics
  List<int> splits25m;
  List<int> splits50m;
  List<double> speedPer25m;
  List<int> strokesPer25m;
  List<double> frequencyPer25m;
  List<double> strokeLengthPer25m;

  RaceAnalyze({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    this.eventName,
    this.raceName,
    this.raceAnalyzeRequestId,
    this.raceDate,
    this.poolLength,
    this.stroke,
    this.distance,
    this.aiInterpretation,
    required this.segments,
    required this.finalTime,
    required this.totalDistance,
    required this.totalStrokes,
    required this.averageSpeedMetersPerSecond,
    required this.averageStrokeFrequency,
    required this.averageStrokeLengthMeters,
    required this.splits25m,
    required this.splits50m,
    required this.speedPer25m,
    required this.strokesPer25m,
    required this.frequencyPer25m,
    required this.strokeLengthPer25m,
  }) {
    this.id = id;
    this.coachId = coachId;
    this.swimmerId = swimmerId;
    this.swimmerName = swimmerName;
  }

  // ---------------------------------------------------------------------------
  // 🔥 FACTORY: Build from RaceSegment (computation layer)
  // ---------------------------------------------------------------------------
  factory RaceAnalyze.fromSegments({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    required String eventName,
    required String raceName,
    required DateTime raceDate,
    required PoolLength poolLength,
    required Stroke stroke,
    required int distance,
    required List<RaceSegment> segments,
  }) {
    // Summary stats from RaceSegment directly
    final finalTime = segments.fold<int>(
      0,
      (int sum, s) => sum + s.splitTimeMillis,
    );

    final totalDistance = segments.fold<double>(
      0.0,
      (double sum, s) => sum + s.segmentDistance,
    );

    final totalStrokes = segments.fold<int>(
      0,
      (int sum, s) => sum + (s.strokes ?? 0),
    );

    final averageSpeed = finalTime > 0
        ? totalDistance / (finalTime / 1000.0)
        : 0.0;

    // Weighted metrics (time-weighted freq, distance-weighted stroke length)
    double weightedFreq = 0;
    int freqTime = 0;

    double weightedLength = 0;
    double totalLengthDist = 0;

    for (final s in segments) {
      if (s.strokeFreq != null) {
        weightedFreq += s.strokeFreq! * s.splitTimeMillis;
        freqTime += s.splitTimeMillis;
      }
      if (s.strokeLength != null) {
        weightedLength += s.strokeLength! * s.segmentDistance;
        totalLengthDist += s.segmentDistance;
      }
    }

    final avgFreq = freqTime > 0 ? weightedFreq / freqTime : 0.0;
    final avgLength = totalLengthDist > 0
        ? weightedLength / totalLengthDist
        : 0.0;

    // Standardized metrics
    final splits25m = _calculateStandardizedSplits(segments, 25);
    final splits50m = _calculateStandardizedSplits(segments, 50);
    final speedPer25m = _calculateSpeedPer25m(splits25m);

    final metrics25 = _calculateMetricsPer25m(segments, splits25m.length);

    return RaceAnalyze(
      id: id,
      coachId: coachId,
      swimmerId: swimmerId,
      swimmerName: swimmerName,
      eventName: eventName,
      raceName: raceName,
      raceDate: raceDate,
      poolLength: poolLength,
      stroke: stroke,
      distance: distance,
      segments: segments,
      finalTime: finalTime,
      totalDistance: totalDistance,
      totalStrokes: totalStrokes,
      averageSpeedMetersPerSecond: averageSpeed,
      averageStrokeFrequency: avgFreq,
      averageStrokeLengthMeters: avgLength,
      splits25m: splits25m,
      splits50m: splits50m,
      speedPer25m: speedPer25m,
      strokesPer25m: metrics25.strokes,
      frequencyPer25m: metrics25.frequencies,
      strokeLengthPer25m: metrics25.lengths,
    );
  }

  // ---------------------------------------------------------------------------
  // 📊 SPEED PER 25m
  // ---------------------------------------------------------------------------
  static List<double> _calculateSpeedPer25m(List<int> splits) {
    if (splits.isEmpty) return [];

    final speeds = <double>[];
    int prev = 0;

    for (final t in splits) {
      final dt = t - prev;
      speeds.add(dt > 0 ? 25.0 / (dt / 1000.0) : 0.0);
      prev = t;
    }

    return speeds;
  }

  // ---------------------------------------------------------------------------
  // 📊 PER-25m METRICS (Strokes / Frequency / Stroke Length)
  // ---------------------------------------------------------------------------
  static Per25mMetrics _calculateMetricsPer25m(
    List<RaceSegment> segments,
    int intervals,
  ) {
    if (segments.isEmpty) {
      return Per25mMetrics(strokes: [], frequencies: [], lengths: []);
    }

    final strokes = <int>[];
    final freqs = <double>[];
    final lengths = <double>[];

    double cumulativeDist = 0;
    int idx = 0;

    for (int i = 0; i < intervals; i++) {
      final target = (i * 25.0) + 12.5;

      while (idx < segments.length - 1 &&
          cumulativeDist + segments[idx].segmentDistance < target) {
        cumulativeDist += segments[idx].segmentDistance;
        idx++;
      }

      final s = segments[idx];

      strokes.add(s.strokes ?? 0);
      freqs.add(s.strokeFreq ?? 0.0);
      lengths.add(s.strokeLength ?? 0.0);
    }

    return Per25mMetrics(
      strokes: strokes,
      frequencies: freqs,
      lengths: lengths,
    );
  }

  // ---------------------------------------------------------------------------
  // 📊 STANDARDIZED SPLIT CALCULATION
  // ---------------------------------------------------------------------------
  static List<int> _calculateStandardizedSplits(
    List<RaceSegment> segments,
    int intervalDistance,
  ) {
    if (segments.isEmpty) return [];

    final splits = <int>[];
    double cumulativeDist = 0;
    int cumulativeTime = 0;
    int index = 0;

    final totalDistance = segments.fold(
      0.0,
      (double sum, s) => sum + s.segmentDistance,
    );

    double target = intervalDistance.toDouble();

    while (target <= totalDistance + 0.1) {
      while (index < segments.length &&
          cumulativeDist + segments[index].segmentDistance < target) {
        cumulativeTime += segments[index].splitTimeMillis;
        cumulativeDist += segments[index].segmentDistance;
        index++;
      }

      if (index >= segments.length) break;

      final seg = segments[index];
      final distIntoSeg = target - cumulativeDist;

      if (seg.segmentDistance <= 0) {
        splits.add(cumulativeTime);
      } else {
        final frac = distIntoSeg / seg.segmentDistance;
        final dt = (frac * seg.splitTimeMillis).round();
        splits.add(cumulativeTime + dt);
      }

      target += intervalDistance;
    }

    return splits;
  }

  // --- FIRESTORE SERIALIZATION ---
  Map<String, dynamic> toJson() {
    return {
      ...analyzableBaseToJson(),
      'eventName': eventName,
      'raceName': raceName,
      'raceAnalyzeRequestId': raceAnalyzeRequestId,
      if (raceDate != null) 'raceDate': Timestamp.fromDate(raceDate!),
      if (poolLength != null) 'poolLength': poolLength!.name,
      if (stroke != null) 'stroke': stroke!.name,
      'distance': distance,
      'segments': segments.map((s) => s.toJson()).toList(),
      // RaceSegment -> json
      'finalTime': finalTime,
      'totalDistance': totalDistance,
      'totalStrokes': totalStrokes,
      'averageSpeedMetersPerSecond': averageSpeedMetersPerSecond,
      'averageStrokeFrequency': averageStrokeFrequency,
      'averageStrokeLengthMeters': averageStrokeLengthMeters,
      'splits25m': splits25m,
      'splits50m': splits50m,
      'speedPer25m': speedPer25m,
      'strokesPer25m': strokesPer25m,
      'frequencyPer25m': frequencyPer25m,
      'strokeLengthPer25m': strokeLengthPer25m,
      'aiInterpretation': aiInterpretation,
    };
  }

  Map<String, dynamic> toAiJson() {
    return {
      "eventName": eventName,
      "raceName": raceName,
      "raceDate": raceDate?.toIso8601String(),
      "poolLength": poolLength?.name,
      "stroke": stroke?.name,
      "distance": distance,
      "segments": segments.map((s) => s.toAiJson()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // 🔥 FIRESTORE DESERIALIZATION
  // ---------------------------------------------------------------------------
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
        'distance',
        'value',
        'meters',
        'meter',
        'm',
        'count',
        'total',
        'milliseconds',
        'millis',
        'ms',
        'time',
        'seconds',
        'sec',
        's',
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

  static int? _parseInt(dynamic raw) => _parseNum(raw)?.round();

  static double? _parseDouble(dynamic raw) => _parseNum(raw)?.toDouble();

  static double _parseDoubleOrZero(dynamic raw) => _parseDouble(raw) ?? 0.0;

  static int? _parseDistance(dynamic raw) => _parseInt(raw);

  static String? _parseString(
    dynamic raw, {
    List<String> preferredKeys = const ['name', 'value', 'type'],
  }) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (raw is num || raw is bool) return raw.toString();

    if (raw is Map) {
      for (final key in preferredKeys) {
        final parsed = _parseString(raw[key], preferredKeys: preferredKeys);
        if (parsed != null) return parsed;
      }
      for (final value in raw.values) {
        final parsed = _parseString(value, preferredKeys: preferredKeys);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Map) {
      final seconds = _parseInt(raw['_seconds'] ?? raw['seconds']);
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      }
      final millis = _parseInt(
        raw['milliseconds'] ?? raw['millis'] ?? raw['ms'] ?? raw['value'],
      );
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    }
    return null;
  }

  static PoolLength _parsePoolLength(dynamic raw) {
    final candidate = _parseString(
      raw,
      preferredKeys: const ['poolLength', 'name', 'value', 'type'],
    );
    if (candidate == null) return PoolLength.unknown;

    for (final value in PoolLength.values) {
      if (value.name == candidate) return value;
    }
    return PoolLength.unknown;
  }

  static Stroke _parseStroke(dynamic raw) {
    final candidate = _parseString(
      raw,
      preferredKeys: const ['stroke', 'name', 'value', 'type'],
    );
    if (candidate == null) return Stroke.unknown;

    for (final value in Stroke.values) {
      if (value.name == candidate) return value;
    }
    return Stroke.unknown;
  }

  static List<dynamic> _rawList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final values = raw['values'] ?? raw['items'] ?? raw['list'];
      if (values is List) return values;
      return raw.values.toList();
    }
    return const [];
  }

  static List<int> _parseIntList(dynamic raw) =>
      _rawList(raw).map(_parseInt).whereType<int>().toList();

  static List<double> _parseDoubleList(dynamic raw) =>
      _rawList(raw).map(_parseDouble).whereType<double>().toList();

  static List<RaceSegment> _parseSegments(dynamic raw) {
    final parsed = <RaceSegment>[];
    for (final item in _rawList(raw)) {
      if (item is Map<String, dynamic>) {
        parsed.add(RaceSegment.fromMap(item));
      } else if (item is Map) {
        parsed.add(RaceSegment.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    return parsed;
  }

  factory RaceAnalyze.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    final race = RaceAnalyze(
      id: doc.id,
      raceAnalyzeRequestId: _parseString(data['raceAnalyzeRequestId']),
      eventName: _parseString(data['eventName']),
      raceName: _parseString(data['raceName']),
      aiInterpretation: _parseString(data['aiInterpretation']),
      raceDate: _parseDate(data['raceDate']),
      poolLength: _parsePoolLength(data['poolLength']),
      stroke: _parseStroke(data['stroke']),
      distance: _parseDistance(data['distance']),
      segments: _parseSegments(data['segments']),
      finalTime: _parseInt(data['finalTime']) ?? 0,
      totalDistance: _parseDoubleOrZero(data['totalDistance']),
      totalStrokes: _parseInt(data['totalStrokes']) ?? 0,
      averageSpeedMetersPerSecond: _parseDoubleOrZero(
        data['averageSpeedMetersPerSecond'],
      ),
      averageStrokeFrequency: _parseDoubleOrZero(
        data['averageStrokeFrequency'],
      ),
      averageStrokeLengthMeters: _parseDoubleOrZero(
        data['averageStrokeLengthMeters'],
      ),
      splits25m: _parseIntList(data['splits25m']),
      splits50m: _parseIntList(data['splits50m']),
      speedPer25m: _parseDoubleList(data['speedPer25m']),
      strokesPer25m: _parseIntList(data['strokesPer25m']),
      frequencyPer25m: _parseDoubleList(data['frequencyPer25m']),
      strokeLengthPer25m: _parseDoubleList(data['strokeLengthPer25m']),
    );

    race.loadAnalyzableBase(data, doc.id);
    return race;
  }

  RaceAnalyze copyWith({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    String? eventName,
    String? raceName,
    DateTime? raceDate,
    PoolLength? poolLength,
    Stroke? stroke,
    int? distance,
    String? aiInterpretation,
    List<RaceSegment>? segments,
    int? finalTime,
    double? totalDistance,
    int? totalStrokes,
    double? averageSpeedMetersPerSecond,
    double? averageStrokeFrequency,
    double? averageStrokeLengthMeters,
    List<int>? splits25m,
    List<int>? splits50m,
    List<double>? speedPer25m,
    List<int>? strokesPer25m,
    List<double>? frequencyPer25m,
    List<double>? strokeLengthPer25m,
  }) {
    final copy = RaceAnalyze(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      swimmerId: swimmerId ?? this.swimmerId,
      swimmerName: swimmerName ?? this.swimmerName,
      eventName: eventName ?? this.eventName,
      raceName: raceName ?? this.raceName,
      raceDate: raceDate ?? this.raceDate,
      poolLength: poolLength ?? this.poolLength,
      stroke: stroke ?? this.stroke,
      distance: distance ?? this.distance,
      aiInterpretation: aiInterpretation ?? this.aiInterpretation,
      segments: segments ?? this.segments,
      finalTime: finalTime ?? this.finalTime,
      totalDistance: totalDistance ?? this.totalDistance,
      totalStrokes: totalStrokes ?? this.totalStrokes,
      averageSpeedMetersPerSecond:
          averageSpeedMetersPerSecond ?? this.averageSpeedMetersPerSecond,
      averageStrokeFrequency:
          averageStrokeFrequency ?? this.averageStrokeFrequency,
      averageStrokeLengthMeters:
          averageStrokeLengthMeters ?? this.averageStrokeLengthMeters,
      splits25m: splits25m ?? this.splits25m,
      splits50m: splits50m ?? this.splits50m,
      speedPer25m: speedPer25m ?? this.speedPer25m,
      strokesPer25m: strokesPer25m ?? this.strokesPer25m,
      frequencyPer25m: frequencyPer25m ?? this.frequencyPer25m,
      strokeLengthPer25m: strokeLengthPer25m ?? this.strokeLengthPer25m,
    );

    return copy;
  }
}
