import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/analyzes/race_analyze.dart';

void main() {
  group('RaceAnalyze.fromFirestore distance parsing', () {
    Future<RaceAnalyze> parseRaceWithDistance(dynamic distance) async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('racesAnalyzes')
          .doc('race_1')
          .set(_baseRaceDoc(distance: distance));

      final snap = await firestore
          .collection('racesAnalyzes')
          .doc('race_1')
          .get();
      return RaceAnalyze.fromFirestore(snap);
    }

    test('parses distance when stored as int', () async {
      final race = await parseRaceWithDistance(100);
      expect(race.distance, 100);
    });

    test('parses distance when stored as map with value key', () async {
      final race = await parseRaceWithDistance({
        'value': 200,
        'unit': 'meters',
      });
      expect(race.distance, 200);
    });

    test('parses distance when stored as nested map', () async {
      final race = await parseRaceWithDistance({
        'distance': {'meters': '50'},
      });
      expect(race.distance, 50);
    });

    test('does not throw when distance map has no numeric payload', () async {
      final race = await parseRaceWithDistance({'unit': 'meters'});
      expect(race.distance, isNull);
    });
  });

  group('RaceAnalyze.fromFirestore segment parsing', () {
    Future<RaceAnalyze> parseRaceWithSegmentPatch(
      Map<String, dynamic> segmentPatch,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final doc = _baseRaceDoc(distance: 100);
      final segments = List<Map<String, dynamic>>.from(
        (doc['segments'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      segments[0].addAll(segmentPatch);
      doc['segments'] = segments;

      await firestore.collection('racesAnalyzes').doc('race_2').set(doc);

      final snap = await firestore
          .collection('racesAnalyzes')
          .doc('race_2')
          .get();
      return RaceAnalyze.fromFirestore(snap);
    }

    test('parses wrapped integer fields in segments', () async {
      final race = await parseRaceWithSegmentPatch({
        'breaths': {'value': '18'},
      });

      expect(race.segments, isNotEmpty);
      expect(race.segments.first.breaths, 18);
    });

    test(
      'keeps optional segment value null when wrapped map is non numeric',
      () async {
        final race = await parseRaceWithSegmentPatch({
          'strokes': {'unit': 'count'},
        });

        expect(race.segments.first.strokes, isNull);
      },
    );
  });

  group('RaceAnalyze.fromFirestore race-level metric parsing', () {
    Future<RaceAnalyze> parseRaceWithTopLevelPatch(
      Map<String, dynamic> patch,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final doc = _baseRaceDoc(distance: 100);
      doc.addAll(patch);
      await firestore.collection('racesAnalyzes').doc('race_3').set(doc);

      final snap = await firestore
          .collection('racesAnalyzes')
          .doc('race_3')
          .get();
      return RaceAnalyze.fromFirestore(snap);
    }

    test('parses wrapped race summary values without throwing', () async {
      final race = await parseRaceWithTopLevelPatch({
        'finalTime': {'milliseconds': 60000},
        'totalDistance': {'meters': 100.0},
        'totalStrokes': {'value': '36'},
        'averageSpeedMetersPerSecond': {'value': '1.67'},
        'splits25m': [
          {'value': '15000'},
          30000,
          {'milliseconds': 45000},
          '60000',
        ],
      });

      expect(race.finalTime, 60000);
      expect(race.totalDistance, 100.0);
      expect(race.totalStrokes, 36);
      expect(race.averageSpeedMetersPerSecond, closeTo(1.67, 0.0001));
      expect(race.splits25m, [15000, 30000, 45000, 60000]);
    });
  });
}

Map<String, dynamic> _baseRaceDoc({required dynamic distance}) {
  return {
    'eventName': 'Race Event',
    'raceName': '100 Freestyle',
    'raceAnalyzeRequestId': 'req_1',
    'aiInterpretation': 'Solid race',
    'raceDate': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
    'poolLength': 'm25',
    'stroke': 'freestyle',
    'distance': distance,
    'segments': [
      {
        'sequence': 1,
        'checkPoint': 'finish',
        'accumulatedDistance': 100.0,
        'segmentDistance': 100.0,
        'splitTimeMillis': 60000,
        'totalTimeMillis': 60000,
        'underwaterDistance': 5.0,
        'strokes': 36,
        'dolphinKicks': 4,
        'breaths': 18,
        'avgSpeed': 1.67,
        'strokeFreq': 32.0,
        'strokeLength': 2.4,
        'strokeIndex': 4.0,
        'breakoutTime': 1200,
      },
    ],
    'finalTime': 60000,
    'totalDistance': 100.0,
    'totalStrokes': 36,
    'averageSpeedMetersPerSecond': 1.67,
    'averageStrokeFrequency': 32.0,
    'averageStrokeLengthMeters': 2.4,
    'splits25m': [15000, 30000, 45000, 60000],
    'splits50m': [30000, 60000],
    'speedPer25m': [1.67, 1.67, 1.67, 1.67],
    'strokesPer25m': [9, 9, 9, 9],
    'frequencyPer25m': [32.0, 32.0, 32.0, 32.0],
    'strokeLengthPer25m': [2.4, 2.4, 2.4, 2.4],
    'createdAt': '2026-01-01T00:00:00.000Z',
  };
}
