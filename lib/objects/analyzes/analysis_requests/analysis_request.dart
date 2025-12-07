import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

class AnalysisRequest {
  final String id;

  final String sessionId;
  final String analysisType;

  final String name;
  final String email;

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
    this.processed = false,
    this.heat,
    this.lane,
    this.distance,
    this.stroke,
    this.productId,
  });

  // ---------------------------------------------------------------------------
  // FROM JSON (Firestore → Model)
  // ---------------------------------------------------------------------------
  factory AnalysisRequest.fromJson(Map<String, dynamic> json, String id) {
    final int distance = json['distance'] != null && json['distance'] is String
        ? int.tryParse(json['distance']) ?? 100
        : json['distance'];
    return AnalysisRequest(
      id: id,
      sessionId: json['sessionId'] as String,
      analysisType: json['analysisType'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      heat: json['heat'] as String?,
      lane: json['lane'] as String?,
      distance: distance,
      stroke: json['focus'] != null
          ? Stroke.fromString(json['focus'])
          : Stroke.unknown,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      verifiedAt: json['verifiedAt'] != null
          ? (json['verifiedAt'] as Timestamp).toDate()
          : null,
      processed: json['processed'] as bool? ?? false,
      productId: json['productId'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // TO JSON (Model → Firestore)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "sessionId": sessionId,
      "analysisType": analysisType,
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
      distance: distance,
      stroke: stroke,
      createdAt: createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      processed: processed ?? this.processed,
      productId: productId,
    );
  }
}
