import 'package:cloud_firestore/cloud_firestore.dart';

class SwimAnalyzerSubscription {
  final String id;
  final String owner;
  final String status;
  final List<String> memberUids;
  final String planId;
  final DateTime? currentPeriodEnd;

  SwimAnalyzerSubscription({
    required this.id,
    required this.owner,
    required this.status,
    required this.memberUids,
    required this.planId,
    this.currentPeriodEnd,
  });

  factory SwimAnalyzerSubscription.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return SwimAnalyzerSubscription(
      id: id,
      owner: data['owner'] as String,
      status: data['status'] as String,
      memberUids: List<String>.from(data['memberUids'] ?? []),
      planId: data['planId'] as String,
      currentPeriodEnd: data['currentPeriodEnd'] != null
          ? (data['currentPeriodEnd'] as Timestamp).toDate()
          : null,
    );
  }
}
