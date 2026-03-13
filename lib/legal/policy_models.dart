import 'package:cloud_firestore/cloud_firestore.dart';

enum PolicyDocumentType { terms, privacy }

class PolicyDocumentRef {
  const PolicyDocumentRef({
    required this.type,
    required this.version,
    required this.effectiveAt,
    required this.url,
    required this.content,
    required this.contextKey,
    required this.updatedAt,
  });

  final PolicyDocumentType type;
  final String version;
  final DateTime? effectiveAt;
  final String url;
  final String content;
  final String contextKey;
  final DateTime? updatedAt;

  bool get hasRequiredFields =>
      version.trim().isNotEmpty &&
      (url.trim().isNotEmpty || content.trim().isNotEmpty);

  factory PolicyDocumentRef.fromMap(
    Map<String, dynamic> map, {
    required PolicyDocumentType type,
    required String contextKey,
  }) {
    return PolicyDocumentRef(
      type: type,
      version: (map['version'] as String? ?? '').trim(),
      effectiveAt: _toDateTime(map['effectiveAt']),
      url: (map['url'] as String? ?? '').trim(),
      content: (map['content'] as String? ?? '').trim(),
      contextKey: contextKey.trim(),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'effectiveAt': effectiveAt,
      'url': url,
      'content': content,
      'updatedAt': updatedAt,
    };
  }
}

class PolicyBundle {
  const PolicyBundle({
    required this.appId,
    required this.contextKey,
    required this.terms,
    required this.privacy,
    required this.publishedBy,
    required this.publishedAt,
  });

  final String appId;
  final String contextKey;
  final PolicyDocumentRef terms;
  final PolicyDocumentRef privacy;
  final String publishedBy;
  final DateTime? publishedAt;

  bool get isValid =>
      appId.trim().isNotEmpty &&
      terms.hasRequiredFields &&
      privacy.hasRequiredFields;

  factory PolicyBundle.fromMap(
    Map<String, dynamic> map, {
    required String contextKey,
  }) {
    final effectiveContext = (map['contextKey'] as String? ?? contextKey)
        .trim();
    final termsMap = map['terms'] is Map
        ? Map<String, dynamic>.from(map['terms'] as Map)
        : const <String, dynamic>{};
    final privacyMap = map['privacy'] is Map
        ? Map<String, dynamic>.from(map['privacy'] as Map)
        : const <String, dynamic>{};

    return PolicyBundle(
      appId: (map['appId'] as String? ?? '').trim(),
      contextKey: effectiveContext,
      terms: PolicyDocumentRef.fromMap(
        termsMap,
        type: PolicyDocumentType.terms,
        contextKey: effectiveContext,
      ),
      privacy: PolicyDocumentRef.fromMap(
        privacyMap,
        type: PolicyDocumentType.privacy,
        contextKey: effectiveContext,
      ),
      publishedBy: (map['publishedBy'] as String? ?? '').trim(),
      publishedAt: _toDateTime(map['publishedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appId': appId,
      'contextKey': contextKey,
      'terms': terms.toMap(),
      'privacy': privacy.toMap(),
      'publishedBy': publishedBy,
      'publishedAt': publishedAt,
    };
  }
}

class UserPolicyAcceptance {
  const UserPolicyAcceptance({
    required this.uid,
    required this.appId,
    required this.contextKey,
    required this.termsVersionAccepted,
    required this.privacyVersionAccepted,
    required this.acceptedAt,
  });

  final String uid;
  final String appId;
  final String contextKey;
  final String termsVersionAccepted;
  final String privacyVersionAccepted;
  final DateTime? acceptedAt;

  factory UserPolicyAcceptance.fromMap(
    Map<String, dynamic> map, {
    required String uid,
    required String contextKey,
  }) {
    return UserPolicyAcceptance(
      uid: uid.trim(),
      appId: (map['appId'] as String? ?? '').trim(),
      contextKey: (map['contextKey'] as String? ?? contextKey).trim(),
      termsVersionAccepted: (map['termsVersionAccepted'] as String? ?? '')
          .trim(),
      privacyVersionAccepted: (map['privacyVersionAccepted'] as String? ?? '')
          .trim(),
      acceptedAt: _toDateTime(map['acceptedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'appId': appId,
      'contextKey': contextKey,
      'termsVersionAccepted': termsVersionAccepted,
      'privacyVersionAccepted': privacyVersionAccepted,
      'acceptedAt': acceptedAt,
    };
  }
}

class PolicyGateDecision {
  const PolicyGateDecision({
    required this.bundle,
    required this.acceptance,
    required this.requiresAcceptance,
    required this.termsAccepted,
    required this.privacyAccepted,
  });

  final PolicyBundle bundle;
  final UserPolicyAcceptance? acceptance;
  final bool requiresAcceptance;
  final bool termsAccepted;
  final bool privacyAccepted;
}

PolicyGateDecision evaluatePolicyGateDecision({
  required PolicyBundle bundle,
  required UserPolicyAcceptance? acceptance,
}) {
  final termsAccepted =
      acceptance != null &&
      acceptance.termsVersionAccepted == bundle.terms.version &&
      acceptance.contextKey == bundle.contextKey;
  final privacyAccepted =
      acceptance != null &&
      acceptance.privacyVersionAccepted == bundle.privacy.version &&
      acceptance.contextKey == bundle.contextKey;

  return PolicyGateDecision(
    bundle: bundle,
    acceptance: acceptance,
    requiresAcceptance: !(termsAccepted && privacyAccepted),
    termsAccepted: termsAccepted,
    privacyAccepted: privacyAccepted,
  );
}

DateTime? _toDateTime(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
