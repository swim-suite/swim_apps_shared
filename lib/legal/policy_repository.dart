import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'policy_models.dart';

class PolicyRepository {
  PolicyRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreOverride = firestore,
      _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<PolicyBundle> fetchCurrentBundle({
    required String appId,
    String contextKey = 'default',
  }) async {
    final normalizedContext = _normalizeContextKey(contextKey);
    try {
      final callable = _functions.httpsCallable('policyGetCurrentBundle');
      final response = await callable.call(<String, dynamic>{
        'contextKey': normalizedContext,
      });
      final payload = _asMap(response.data);
      final bundleMap = payload['bundle'] is Map
          ? Map<String, dynamic>.from(payload['bundle'] as Map)
          : payload;
      final bundle = PolicyBundle.fromMap(
        bundleMap,
        contextKey: normalizedContext,
      );
      if (!bundle.isValid) {
        throw StateError('Invalid policy bundle payload.');
      }
      if (bundle.appId.isNotEmpty && bundle.appId != appId.trim()) {
        throw StateError('Policy appId mismatch.');
      }
      return bundle;
    } catch (_) {
      final snapshot = await _firestore
          .collection('policy_bundles')
          .doc(normalizedContext)
          .get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError(
          'No policy bundle published for context $normalizedContext.',
        );
      }
      final bundle = PolicyBundle.fromMap(
        snapshot.data()!,
        contextKey: normalizedContext,
      );
      if (!bundle.isValid) {
        throw StateError(
          'Invalid policy bundle in Firestore for context $normalizedContext.',
        );
      }
      if (bundle.appId != appId.trim()) {
        throw StateError('Policy appId mismatch.');
      }
      return bundle;
    }
  }

  Stream<UserPolicyAcceptance?> watchUserAcceptance({
    required String uid,
    required String appId,
    String contextKey = 'default',
  }) {
    final normalizedUid = uid.trim();
    final normalizedContext = _normalizeContextKey(contextKey);

    if (normalizedUid.isEmpty) {
      return const Stream<UserPolicyAcceptance?>.empty();
    }

    return _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('policy_acceptance')
        .doc(normalizedContext)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return null;
          final acceptance = UserPolicyAcceptance.fromMap(
            data,
            uid: normalizedUid,
            contextKey: normalizedContext,
          );
          if (acceptance.appId.isNotEmpty && acceptance.appId != appId.trim()) {
            return null;
          }
          return acceptance;
        });
  }

  Future<UserPolicyAcceptance?> getUserAcceptance({
    required String uid,
    required String appId,
    String contextKey = 'default',
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('policy_acceptance')
        .doc(_normalizeContextKey(contextKey))
        .get();
    final data = snapshot.data();
    if (data == null) return null;

    final acceptance = UserPolicyAcceptance.fromMap(
      data,
      uid: normalizedUid,
      contextKey: _normalizeContextKey(contextKey),
    );
    if (acceptance.appId.isNotEmpty && acceptance.appId != appId.trim()) {
      return null;
    }
    return acceptance;
  }

  Future<void> acceptCurrentBundle({
    required String appId,
    required String contextKey,
    required String termsVersion,
    required String privacyVersion,
  }) async {
    final callable = _functions.httpsCallable('policyAcceptCurrentBundle');
    await callable.call(<String, dynamic>{
      'appId': appId.trim(),
      'contextKey': _normalizeContextKey(contextKey),
      'termsVersion': termsVersion.trim(),
      'privacyVersion': privacyVersion.trim(),
    });
  }

  Future<PolicyGateDecision> checkAccess({
    required String uid,
    required String appId,
    String contextKey = 'default',
  }) async {
    final bundle = await fetchCurrentBundle(
      appId: appId,
      contextKey: contextKey,
    );
    final acceptance = await getUserAcceptance(
      uid: uid,
      appId: appId,
      contextKey: contextKey,
    );
    return evaluatePolicyGateDecision(bundle: bundle, acceptance: acceptance);
  }

  String _normalizeContextKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'default';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }
}
