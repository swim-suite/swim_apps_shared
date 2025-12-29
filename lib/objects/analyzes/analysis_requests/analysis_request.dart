import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

import 'analysis_request_type.dart';

class AnalysisRequest {
  final String id;

  final String sessionId;
  final AnalysisRequestType analysisType;

  final String name;
  final String email;
  final bool isShortCourse;

  final String videoUrl;

  // Race fields
  final String? heat;
  final String? lane;
  final int? distance;
  final Stroke? stroke;

  final DateTime createdAt;
  final DateTime? verifiedAt;

  final bool processed;

  final String? productId;

  const AnalysisRequest({
    required this.id,
    required this.sessionId,
    required this.analysisType,
    required this.name,
    required this.email,
    required this.videoUrl,
    required this.createdAt,
    this.verifiedAt,
    this.isShortCourse = true,
    this.processed = false,
    this.heat,
    this.lane,
    this.distance,
    this.stroke,
    this.productId,
  });

  // ---------------------------------------------------------------------------
  // FROM JSON
  // ---------------------------------------------------------------------------
  factory AnalysisRequest.fromJson(
      {required Map<String, dynamic> json, required String id}) {
    final int distance = _parseDistance(json['distance']);

    return AnalysisRequest(
      id: id,
      sessionId: json['sessionId'] as String,
      analysisType: AnalysisRequestType.values.firstWhere(
        (e) => e.name == json['analysisType'],
        orElse: () => AnalysisRequestType.raceAnalyze,
      ),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isShortCourse: json['isShortCourse'] ?? true,
      videoUrl: json['videoUrl'] as String? ?? '',
      heat: json['heat'] as String?,
      lane: json['lane'] as String?,
      distance: distance,
      stroke: json['stroke'] != null
          ? Stroke.fromString(json['stroke'])
          : Stroke.unknown,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      verifiedAt: json['verifiedAt'] != null
          ? (json['verifiedAt'] as Timestamp).toDate()
          : null,
      processed: json['processed'] as bool? ?? false,
      productId: json['productId'] as String?,
    );
  }

  static int _parseDistance(dynamic raw) {
    if (raw == null) return 100;

    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) return int.tryParse(raw) ?? 100;

    return 100;
  }

  // ---------------------------------------------------------------------------
  // TO JSON (Model → Firestore)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "sessionId": sessionId,
      "analysisType": analysisType.name,
      "name": name,
      "email": email,
      "videoUrl": videoUrl,
      "heat": heat,
      "lane": lane,
      "distance": distance,
      if (stroke != null) "stroke": stroke!.name,
      "createdAt": Timestamp.fromDate(createdAt),
      "verifiedAt": verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      "processed": processed,
      "productId": productId,
    };
  }

  // ---------------------------------------------------------------------------
  // COPY WITH — useful for updating processed=true or adding PDF URL later
  // ---------------------------------------------------------------------------
  AnalysisRequest copyWith({
    String? paymentStatus,
    bool? processed,
    DateTime? verifiedAt,
    Stroke? stroke,
    int? distance,
  }) {
    return AnalysisRequest(
      id: id,
      sessionId: sessionId,
      analysisType: analysisType,
      name: name,
      email: email,
      videoUrl: videoUrl,
      heat: heat,
      lane: lane,
      distance: distance ?? this.distance,
      stroke: stroke ?? this.stroke,
      createdAt: createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      processed: processed ?? this.processed,
      productId: productId,
    );
  }
}
