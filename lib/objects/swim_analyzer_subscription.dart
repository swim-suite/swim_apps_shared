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
    return SwimAnalyzerSubscription(
      id: id,
      owner: data['owner'] as String,
      memberUids: List<String>.from(data['memberUids'] ?? []),
      planId: data['planId'] as String,
      swimAnalyzerSubscriptionPlanType: SwimAnalyzerSubscriptionPlanType.values
          .firstWhere((planType) => planType.name == data['planType']),
      stripeCustomerId: data['stripeCustomerId'] as String,
      stripePriceId: data['stripePriceId'] as String,
      status: data['status'] as String,
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      currentPeriodEnd: data['currentPeriodEnd'] != null
          ? (data['currentPeriodEnd'] as Timestamp).toDate()
          : null,
    );
  }
}
