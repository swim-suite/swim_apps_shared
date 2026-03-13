import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/legal/policy_models.dart';

void main() {
  PolicyBundle bundle({
    String termsVersion = '2026-03-01',
    String privacyVersion = '2026-03-01',
    String contextKey = 'default',
  }) {
    return PolicyBundle(
      appId: 'aquis',
      contextKey: contextKey,
      terms: PolicyDocumentRef(
        type: PolicyDocumentType.terms,
        version: termsVersion,
        effectiveAt: DateTime.utc(2026, 3, 1),
        url: 'https://example.com/terms',
        contextKey: contextKey,
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
      privacy: PolicyDocumentRef(
        type: PolicyDocumentType.privacy,
        version: privacyVersion,
        effectiveAt: DateTime.utc(2026, 3, 1),
        url: 'https://example.com/privacy',
        contextKey: contextKey,
        updatedAt: DateTime.utc(2026, 3, 1),
      ),
      publishedBy: 'admin_1',
      publishedAt: DateTime.utc(2026, 3, 1),
    );
  }

  test('requires acceptance when no acceptance exists', () {
    final decision = evaluatePolicyGateDecision(
      bundle: bundle(),
      acceptance: null,
    );

    expect(decision.requiresAcceptance, isTrue);
    expect(decision.termsAccepted, isFalse);
    expect(decision.privacyAccepted, isFalse);
  });

  test('accepts only when both versions match', () {
    final decision = evaluatePolicyGateDecision(
      bundle: bundle(),
      acceptance: UserPolicyAcceptance(
        uid: 'u1',
        appId: 'aquis',
        contextKey: 'default',
        termsVersionAccepted: '2026-03-01',
        privacyVersionAccepted: '2026-03-01',
        acceptedAt: DateTime.utc(2026, 3, 2),
      ),
    );

    expect(decision.requiresAcceptance, isFalse);
    expect(decision.termsAccepted, isTrue);
    expect(decision.privacyAccepted, isTrue);
  });

  test(
    'outdated terms forces acceptance while privacy can still be accepted',
    () {
      final decision = evaluatePolicyGateDecision(
        bundle: bundle(
          termsVersion: '2026-03-10',
          privacyVersion: '2026-03-01',
        ),
        acceptance: UserPolicyAcceptance(
          uid: 'u1',
          appId: 'aquis',
          contextKey: 'default',
          termsVersionAccepted: '2026-03-01',
          privacyVersionAccepted: '2026-03-01',
          acceptedAt: DateTime.utc(2026, 3, 2),
        ),
      );

      expect(decision.requiresAcceptance, isTrue);
      expect(decision.termsAccepted, isFalse);
      expect(decision.privacyAccepted, isTrue);
    },
  );

  test('context mismatch forces acceptance', () {
    final decision = evaluatePolicyGateDecision(
      bundle: bundle(contextKey: 'club_a'),
      acceptance: UserPolicyAcceptance(
        uid: 'u1',
        appId: 'aquis',
        contextKey: 'default',
        termsVersionAccepted: '2026-03-01',
        privacyVersionAccepted: '2026-03-01',
        acceptedAt: DateTime.utc(2026, 3, 2),
      ),
    );

    expect(decision.requiresAcceptance, isTrue);
    expect(decision.termsAccepted, isFalse);
    expect(decision.privacyAccepted, isFalse);
  });
}
