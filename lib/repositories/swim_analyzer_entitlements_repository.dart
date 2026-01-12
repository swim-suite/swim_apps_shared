import 'package:cloud_firestore/cloud_firestore.dart';

import '../objects/analyzer_entitlement_plan.dart';
import '../objects/swim_analyzer_subscription.dart';

class SwimAnalyzerEntitlementsRepository {
  final FirebaseFirestore _db;

  SwimAnalyzerEntitlementsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ============================================================
  // PLANS
  // ============================================================

  Stream<List<AnalyzerEntitlementPlan>> watchPlans() {
    return _db
        .collection('entitlements')
        .doc('swim_analyzer')
        .collection('plans')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AnalyzerEntitlementPlan.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  Future<AnalyzerEntitlementPlan?> getPlanById(String planId) async {
    final doc = await _db
        .collection('entitlements')
        .doc('swim_analyzer')
        .collection('plans')
        .doc(planId)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    return AnalyzerEntitlementPlan.fromFirestore(doc.id, doc.data()!);
  }

  // ============================================================
  // SUBSCRIPTIONS (ACTIVE ENTITLEMENTS)
  // ============================================================

  Stream<SwimAnalyzerSubscription?> watchActiveSubscriptionForUser({
    required String userId,
  }) {
    return _db
        .collection('swimAnalyzerSubscriptions')
        .where('status', isEqualTo: 'active')
        .where('memberUids', arrayContains: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return SwimAnalyzerSubscription.fromFirestore(doc.id, doc.data());
    });
  }

  Future<SwimAnalyzerSubscription?> getActiveSubscriptionForUser({
    required String userId,
  }) async {
    final snapshot = await _db
        .collection('swimAnalyzerSubscriptions')
        .where('status', isEqualTo: 'active')
        .where('memberUids', arrayContains: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return SwimAnalyzerSubscription.fromFirestore(doc.id, doc.data());
  }
}
