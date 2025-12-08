import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swim_apps_shared/objects/pool_length.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

import 'analyze_base.dart';
import 'analyzed_segment.dart';

/// Represents a full race analysis, ready to be stored in Firestore.
/// Contains both high-level summary statistics and standardized per-25m data.
class RaceAnalyze with AnalyzableBase {
  String? eventName;
  String? raceName;
  String? raceAnalyzeRequestId;
  DateTime? raceDate;
  PoolLength? poolLength;
  Stroke? stroke;
  int? distance;
  List<AnalyzedSegment> segments;
  final String? aiInterpretation;

  // --- OVERALL RACE SUMMARY STATS ---
  int finalTime; // Total race time in milliseconds
  double totalDistance; // Sum of all segment distances
  int totalStrokes;
  double averageSpeedMetersPerSecond;
  double averageStrokeFrequency;
  double averageStrokeLengthMeters;

  // --- STANDARDIZED INTERVAL STATS ---
  List<int> splits25m;
  List<int> splits50m;
  List<double> speedPer25m;
  List<int> strokesPer25m;
  List<double> frequencyPer25m;
  List<double> strokeLengthPer25m;

  /// Optimization: cache for expensive computed metrics (not stored in Firestore)
  final Map<String, dynamic> _extraData = {};

  RaceAnalyze({
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,
    this.eventName,
    this.raceName,
    this.raceDate,
    this.poolLength,
    this.stroke,
    this.distance,
    this.aiInterpretation,
    this.raceAnalyzeRequestId,
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
    // ✅ Assign mixin fields manually
    this.id = id;
    this.coachId = coachId;
    this.swimmerId = swimmerId;
    this.swimmerName = swimmerName;
  }

  // --- ✅ RESTORED FACTORY ---
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
    required List<AnalyzedSegment> segments,
  }) {
    // --- Overall Summary Calculations ---
    final finalTime =
        segments.map((s) => s.splitTimeMillis).fold(0, (a, b) => a + b);
    final totalDistance =
        segments.map((s) => s.distanceMeters).fold(0.0, (a, b) => a + b);
    final totalStrokes =
        segments.map((s) => s.strokes ?? 0).fold(0, (a, b) => a + b);

    final averageSpeed = (totalDistance > 0 && finalTime > 0)
        ? (totalDistance / (finalTime / 1000.0))
        : 0.0;

    double totalWeightedFreq = 0;
    double totalWeightedLength = 0;
    int totalTimeForFreq = 0;
    double totalDistForLength = 0;

    for (final segment in segments) {
      if (segment.strokeFrequency != null) {
        totalWeightedFreq += segment.strokeFrequency! * segment.splitTimeMillis;
        totalTimeForFreq += segment.splitTimeMillis;
      }
      if (segment.strokeLengthMeters != null) {
        totalWeightedLength +=
            segment.strokeLengthMeters! * segment.distanceMeters;
        totalDistForLength += segment.distanceMeters;
      }
    }

    final avgFreq =
        (totalTimeForFreq > 0) ? totalWeightedFreq / totalTimeForFreq : 0.0;
    final avgLength = (totalDistForLength > 0)
        ? totalWeightedLength / totalDistForLength
        : 0.0;

    // --- Standardized Interval Calculations ---
    final splits25m = _calculateStandardizedSplits(segments, 25);
    final splits50m = _calculateStandardizedSplits(segments, 50);
    final speedPer25m = _calculateSpeedPer25m(splits25m);
    final otherMetrics = _calculateMetricsPer25m(segments, splits25m.length);

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
      strokesPer25m: List<int>.from(otherMetrics['strokes']!),
      frequencyPer25m: List<double>.from(otherMetrics['frequencies']!),
      strokeLengthPer25m: List<double>.from(otherMetrics['lengths']!),
    );
  }

  // --- 🧮 HELPER METHODS (unchanged) ---
  static List<double> _calculateSpeedPer25m(List<int> splits25m) {
    if (splits25m.isEmpty) return [];
    final List<double> speeds = [];
    int previousSplitTime = 0;
    for (final splitTime in splits25m) {
      final intervalTime = splitTime - previousSplitTime;
      final speed = (intervalTime > 0) ? (25.0 / (intervalTime / 1000.0)) : 0.0;
      speeds.add(speed);
      previousSplitTime = splitTime;
    }
    return speeds;
  }

  static Map<String, List<dynamic>> _calculateMetricsPer25m(
    List<AnalyzedSegment> segments,
    int numIntervals,
  ) {
    if (segments.isEmpty) {
      return {'strokes': [], 'frequencies': [], 'lengths': []};
    }

    final List<int> strokes = [];
    final List<double> frequencies = [];
    final List<double> lengths = [];

    double cumulativeDistance = 0;
    int segmentIndex = 0;

    for (int i = 0; i < numIntervals; i++) {
      final double midpointDistance = (i * 25.0) + 12.5;
      while (segmentIndex < segments.length - 1 &&
          (cumulativeDistance + segments[segmentIndex].distanceMeters) <
              midpointDistance) {
        cumulativeDistance += segments[segmentIndex].distanceMeters;
        segmentIndex++;
      }

      final segment = segments[segmentIndex];
      strokes.add(segment.strokes ?? 0);
      frequencies.add(segment.strokeFrequency ?? 0.0);
      lengths.add(segment.strokeLengthMeters ?? 0.0);
    }
    return {'strokes': strokes, 'frequencies': frequencies, 'lengths': lengths};
  }

  static List<int> _calculateStandardizedSplits(
    List<AnalyzedSegment> segments,
    int intervalDistance,
  ) {
    if (segments.isEmpty || intervalDistance <= 0) return [];

    final List<int> splits = [];
    double targetDistance = intervalDistance.toDouble();
    double cumulativeDistance = 0;
    int cumulativeTime = 0;
    int segmentIndex = 0;
    final double totalRaceDistance =
        segments.map((s) => s.distanceMeters).fold(0.0, (a, b) => a + b);

    while (targetDistance <= totalRaceDistance + 0.1) {
      while (segmentIndex < segments.length &&
          (cumulativeDistance + segments[segmentIndex].distanceMeters) <
              targetDistance) {
        cumulativeDistance += segments[segmentIndex].distanceMeters;
        cumulativeTime += segments[segmentIndex].splitTimeMillis;
        segmentIndex++;
      }

      if (segmentIndex >= segments.length) break;

      final currentSegment = segments[segmentIndex];
      final double distanceIntoSegment = targetDistance - cumulativeDistance;

      if (currentSegment.distanceMeters == 0) {
        if (distanceIntoSegment == 0) splits.add(cumulativeTime);
        targetDistance += intervalDistance;
        continue;
      }

      final double fractionOfSegment =
          distanceIntoSegment / currentSegment.distanceMeters;
      final int timeForFraction =
          (fractionOfSegment * currentSegment.splitTimeMillis).round();
      splits.add(cumulativeTime + timeForFraction);
      targetDistance += intervalDistance;
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
      'aiInterpretation': aiInterpretation
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
      "segments": segments.map((AnalyzedSegment s) => s.toAiJson()).toList(),
    };
  }

  factory RaceAnalyze.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final race = RaceAnalyze(
      id: doc.id,
      raceAnalyzeRequestId: data['raceAnalyzeRequestId'] as String?,
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
          .map((s) => AnalyzedSegment.fromMap(s as Map<String, dynamic>))
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
    // from AnalyzableBase / metadata
    String? id,
    String? coachId,
    String? swimmerId,
    String? swimmerName,

    // editable metadata
    String? eventName,
    String? raceName,
    DateTime? raceDate,
    PoolLength? poolLength,
    Stroke? stroke,
    int? distance,

    // NEW
    String? aiInterpretation,

    // core data
    List<AnalyzedSegment>? segments,
    int? finalTime,
    double? totalDistance,
    int? totalStrokes,
    double? averageSpeedMetersPerSecond,
    double? averageStrokeFrequency,
    double? averageStrokeLengthMeters,

    // standardized metrics
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

  // --- CACHE METHODS ---
  void setExtraData(String key, dynamic value) => _extraData[key] = value;

  T? getExtraData<T>(String key) => _extraData[key] as T?;
}
