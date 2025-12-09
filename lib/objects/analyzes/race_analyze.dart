import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swim_apps_shared/objects/pool_length.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

import '../per_25.dart';
import '../race_segment.dart';
import 'analyze_base.dart';
import 'analyzed_segment.dart';

/// Full race analysis stored in Firestore.
/// Uses legacy `AnalyzedSegment` for storage,
/// but accepts *RaceSegment* in the factory.
class RaceAnalyze with AnalyzableBase {
  String? eventName;
  String? raceName;
  String? raceAnalyzeRequestId;
  DateTime? raceDate;
  PoolLength? poolLength;
  Stroke? stroke;
  int? distance;

  /// STORED FORMAT (legacy compatibility)
  List<AnalyzedSegment> segments;

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
    // Convert RaceSegment → AnalyzedSegment (Firestore format)
    final analyzed = segments.map((s) {
      return AnalyzedSegment(
        sequence: s.sequence,
        checkPoint: s.checkPoint,
        distanceMeters: s.segmentDistance,
        totalTimeMillis: s.totalTimeMillis,
        splitTimeMillis: s.splitTimeMillis,
        dolphinKicks: s.dolphinKicks,
        strokes: s.strokes,
        breaths: s.breaths,
        strokeFrequency: s.strokeFreq,
        strokeLengthMeters: s.strokeLength,
        underwaterDistance: s.underwaterDistance,
      );
    }).toList();

    // Summary stats
    final finalTime =
    analyzed.fold<int>(0, (int sum, s) => sum + s.splitTimeMillis);

    final totalDistance =
    analyzed.fold<double>(0.0, (double sum, s) => sum + s.distanceMeters);

    final totalStrokes =
    analyzed.fold<int>(0, (int sum, s) => sum + (s.strokes ?? 0));

    final averageSpeed =
    finalTime > 0 ? totalDistance / (finalTime / 1000.0) : 0.0;

    // Weighted metrics
    double weightedFreq = 0;
    int freqTime = 0;

    double weightedLength = 0;
    double totalLengthDist = 0;

    for (final s in analyzed) {
      if (s.strokeFrequency != null) {
        weightedFreq += s.strokeFrequency! * s.splitTimeMillis;
        freqTime += s.splitTimeMillis;
      }
      if (s.strokeLengthMeters != null) {
        weightedLength += s.strokeLengthMeters! * s.distanceMeters;
        totalLengthDist += s.distanceMeters;
      }
    }

    final avgFreq = freqTime > 0 ? weightedFreq / freqTime : 0.0;
    final avgLength =
    totalLengthDist > 0 ? weightedLength / totalLengthDist : 0.0;

    // Standardized metrics
    final splits25m = _calculateStandardizedSplits(segments, 25);
    final splits50m = _calculateStandardizedSplits(segments, 50);
    final speedPer25m = _calculateSpeedPer25m(splits25m);

    final metrics25 = _calculateMetricsPer25m(analyzed, splits25m.length);

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
      segments: analyzed,
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
  static Per25mMetrics _calculateMetricsPer25m(List<AnalyzedSegment> segments,
      int intervals,) {
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
          cumulativeDist + segments[idx].distanceMeters < target) {
        cumulativeDist += segments[idx].distanceMeters;
        idx++;
      }

      final s = segments[idx];

      strokes.add(s.strokes ?? 0);
      freqs.add(s.strokeFrequency ?? 0.0);
      lengths.add(s.strokeLengthMeters ?? 0.0);
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

    final totalDistance =
    segments.fold(0.0, (double sum, s) => sum + s.segmentDistance);

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

  // ---------------------------------------------------------------------------
  // 🔥 FIRESTORE DESERIALIZATION
  // ---------------------------------------------------------------------------
  factory RaceAnalyze.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    final race = RaceAnalyze(
      id: doc.id,
      raceAnalyzeRequestId: data['raceAnalyzeRequestId'],
      eventName: data['eventName'],
      raceName: data['raceName'],
      aiInterpretation: data['aiInterpretation'],
      raceDate: data['raceDate'] != null
          ? (data['raceDate'] as Timestamp).toDate()
          : null,
      poolLength: PoolLength.values.byName(data['poolLength'] ?? 'unknown'),
      stroke: Stroke.values.byName(data['stroke'] ?? 'unknown'),
      distance: data['distance'],
      segments: (data['segments'] as List<dynamic>)
          .map((e) => AnalyzedSegment.fromMap(e as Map<String, dynamic>))
          .toList(),
      finalTime: data['finalTime'],
      totalDistance: (data['totalDistance'] as num).toDouble(),
      totalStrokes: data['totalStrokes'],
      averageSpeedMetersPerSecond:
          (data['averageSpeedMetersPerSecond'] as num).toDouble(),
      averageStrokeFrequency:
          (data['averageStrokeFrequency'] as num).toDouble(),
      averageStrokeLengthMeters:
          (data['averageStrokeLengthMeters'] as num).toDouble(),
      splits25m: List<int>.from(data['splits25m']),
      splits50m: List<int>.from(data['splits50m']),
      speedPer25m: List<double>.from(data['speedPer25m']),
      strokesPer25m: List<int>.from(data['strokesPer25m']),
      frequencyPer25m: List<double>.from(data['frequencyPer25m']),
      strokeLengthPer25m: List<double>.from(data['strokeLengthPer25m']),
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
    List<AnalyzedSegment>? segments,
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
