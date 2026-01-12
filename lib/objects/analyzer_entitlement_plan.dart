class AnalyzerEntitlementPlan {
  final String id;
  final String name;
  final String description;
  final String planType;
  final String stripePriceId;
  final int? maxInvitedSwimmers;

  AnalyzerEntitlementPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.planType,
    required this.stripePriceId,
    this.maxInvitedSwimmers,
  });

  factory AnalyzerEntitlementPlan.fromFirestore(String id, Map<String, dynamic> data) {
    return AnalyzerEntitlementPlan(
      id: id,
      name: data['name'] as String,
      description: data['description'] as String,
      planType: data['planType'] as String,
      stripePriceId: data['stripePriceId'] as String,
      maxInvitedSwimmers: data['maxInvitedSwimmers'] as int?,
    );
  }
}
