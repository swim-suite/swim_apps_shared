import 'package:cloud_firestore/cloud_firestore.dart';

import 'swim_analyzer_plan_type.dart';

class SwimAnalyzerSubscription {
  final String id;

  // Ownership & access
  final String owner;
  final List<String> memberUids;

  // Plan binding
  final String planId;
  final SwimAnalyzerSubscriptionPlanType swimAnalyzerSubscriptionPlanType;

  // Stripe
  final String stripeCustomerId;
  final String stripePriceId;

  // Lifecycle
  final String status; // active, trialing, canceled, etc.
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;
  final DateTime createdAt;

  SwimAnalyzerSubscription({
    required this.id,
    required this.owner,
    required this.memberUids,
    required this.planId,
    required this.stripeCustomerId,
    required this.stripePriceId,
    required this.status,
    required this.cancelAtPeriodEnd,
    required this.createdAt,
    required this.swimAnalyzerSubscriptionPlanType,
    this.currentPeriodEnd,
  });

  factory SwimAnalyzerSubscription.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawPlanType = (data['planType'] as String?)?.trim().toLowerCase();
    final resolvedPlanType = SwimAnalyzerSubscriptionPlanType.values.firstWhere(
      (planType) => planType.name == rawPlanType,
      orElse: () {
        final planId = (data['planId'] as String?)?.toLowerCase() ?? '';
        if (planId.contains('team') || planId.contains('coach')) {
          return SwimAnalyzerSubscriptionPlanType.team;
        }
        return SwimAnalyzerSubscriptionPlanType.solo;
      },
    );

    DateTime timestampToDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      throw StateError(
          'Expected Timestamp/DateTime but got ${value.runtimeType}');
    }

    return SwimAnalyzerSubscription(
      id: id,
      owner: data['owner'] as String,
      memberUids: List<String>.from(data['memberUids'] ?? []),
      planId: data['planId'] as String,
      swimAnalyzerSubscriptionPlanType: resolvedPlanType,
      stripeCustomerId: data['stripeCustomerId'] as String,
      stripePriceId: data['stripePriceId'] as String,
      status: data['status'] as String,
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
      createdAt: timestampToDateTime(data['createdAt']),
      currentPeriodEnd: data['currentPeriodEnd'] != null
          ? timestampToDateTime(data['currentPeriodEnd'])
          : null,
    );
  }
}
