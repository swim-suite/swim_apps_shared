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
          .map((doc) =>
              AnalyzerEntitlementPlan.fromFirestore(doc.id, doc.data()))
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
        .where('memberUids', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      QueryDocumentSnapshot<Map<String, dynamic>>? activeDoc;
      QueryDocumentSnapshot<Map<String, dynamic>>? trialingDoc;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status']?.toString().toLowerCase();
        if (status == 'active') {
          activeDoc = doc;
          break;
        }
        if (status == 'trialing' && trialingDoc == null) {
          trialingDoc = doc;
        }
      }

      final doc = activeDoc ?? trialingDoc;
      if (doc == null) return null;
      return SwimAnalyzerSubscription.fromFirestore(doc.id, doc.data());
    });
  }

  Future<SwimAnalyzerSubscription?> getActiveSubscriptionForUser({
    required String userId,
  }) async {
    final activeSnapshot = await _db
        .collection('swimAnalyzerSubscriptions')
        .where('status', isEqualTo: 'active')
        .where('memberUids', arrayContains: userId)
        .limit(1)
        .get();

    if (activeSnapshot.docs.isNotEmpty) {
      final activeDoc = activeSnapshot.docs.first;
      return SwimAnalyzerSubscription.fromFirestore(
          activeDoc.id, activeDoc.data());
    }

    final trialingSnapshot = await _db
        .collection('swimAnalyzerSubscriptions')
        .where('status', isEqualTo: 'trialing')
        .where('memberUids', arrayContains: userId)
        .limit(1)
        .get();

    if (trialingSnapshot.docs.isEmpty) return null;

    final trialingDoc = trialingSnapshot.docs.first;
    return SwimAnalyzerSubscription.fromFirestore(
      trialingDoc.id,
      trialingDoc.data(),
    );
  }
}
