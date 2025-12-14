import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/analyzes/analysis_requests/analysis_request.dart';
import 'package:swim_apps_shared/objects/analyzes/analysis_requests/analysis_request_type.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

void main() {
  group('AnalysisRequest.fromJson', () {
    test('parses full valid json correctly', () {
      final createdAt = DateTime(2025, 1, 1);
      final verifiedAt = DateTime(2025, 1, 2);

      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'raceAnalyze',
        'name': 'Johannes',
        'email': 'test@swimsuite.com',
        'videoUrl': 'https://video.url',
        'heat': '1',
        'lane': '4',
        'distance': 50,
        'stroke': 'freestyle',
        'createdAt': Timestamp.fromDate(createdAt),
        'verifiedAt': Timestamp.fromDate(verifiedAt),
        'processed': true,
        'productId': 'prod_123',
        'isShortCourse': false,
      };

      final req = AnalysisRequest.fromJson(json: json, id: 'id_1');

      expect(req.id, 'id_1');
      expect(req.sessionId, 'sess_123');
      expect(req.analysisType, AnalysisRequestType.raceAnalyze);
      expect(req.name, 'Johannes');
      expect(req.email, 'test@swimsuite.com');
      expect(req.videoUrl, 'https://video.url');
      expect(req.heat, '1');
      expect(req.lane, '4');
      expect(req.distance, 50);
      expect(req.stroke, Stroke.freestyle);
      expect(req.createdAt, createdAt);
      expect(req.verifiedAt, verifiedAt);
      expect(req.processed, true);
      expect(req.productId, 'prod_123');
      expect(req.isShortCourse, false);
    });

    test('falls back to raceAnalyze when analysisType is unknown', () {
      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'unknown_type',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final req = AnalysisRequest.fromJson(
        json: json,
        id: 'id',
      );

      expect(req.analysisType, AnalysisRequestType.raceAnalyze);
    });

    test('defaults isShortCourse to true when missing', () {
      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'raceAnalyze',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final req = AnalysisRequest.fromJson(json: json, id: 'id');

      expect(req.isShortCourse, true);
    });

    test('parses distance when provided as string', () {
      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'raceAnalyze',
        'distance': '100',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final req = AnalysisRequest.fromJson(json: json, id: 'id');

      expect(req.distance, 100);
    });

    test('falls back to default distance when string parse fails', () {
      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'raceAnalyze',
        'distance': 'invalid',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final req = AnalysisRequest.fromJson(json: json, id: 'id');

      expect(req.distance, 100);
    });

    test('sets stroke to unknown when missing', () {
      final json = {
        'sessionId': 'sess_123',
        'analysisType': 'raceAnalyze',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      final req = AnalysisRequest.fromJson(json: json, id: 'id');

      expect(req.stroke, Stroke.unknown);
    });
  });

  group('AnalysisRequest.toJson', () {
    test('serializes correctly to Firestore format', () {
      final createdAt = DateTime(2025, 1, 1);

      final req = AnalysisRequest(
        id: 'id',
        sessionId: 'sess',
        analysisType: AnalysisRequestType.raceAnalyze,
        name: 'Name',
        email: 'email@test.com',
        videoUrl: 'url',
        createdAt: createdAt,
        distance: 50,
        stroke: Stroke.butterfly,
        processed: true,
      );

      final json = req.toJson();

      expect(json['sessionId'], 'sess');
      expect(json['analysisType'], 'raceAnalyze');
      expect(json['name'], 'Name');
      expect(json['email'], 'email@test.com');
      expect(json['videoUrl'], 'url');
      expect(json['distance'], 50);
      expect(json['stroke'], 'butterfly');
      expect(json['processed'], true);
      expect(json['createdAt'], isA<Timestamp>());
    });
  });

  group('AnalysisRequest.copyWith', () {
    test('updates only provided fields', () {
      final original = AnalysisRequest(
        id: 'id',
        sessionId: 'sess',
        analysisType: AnalysisRequestType.raceAnalyze,
        name: 'Name',
        email: 'email',
        videoUrl: 'url',
        createdAt: DateTime(2025),
        processed: false,
      );

      final updated = original.copyWith(
        processed: true,
        distance: 50,
      );

      expect(updated.processed, true);
      expect(updated.distance, 50);
      expect(updated.name, original.name);
      expect(updated.sessionId, original.sessionId);
    });
  });
}
