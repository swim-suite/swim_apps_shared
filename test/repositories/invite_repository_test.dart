import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/repositories/invite_repository.dart';

void main() {
  group('InviteRepository.getInvitesByEmail', () {
    test('loads invites from inviteeEmail and receiverEmail', () async {
      final db = FakeFirebaseFirestore();
      final repo = InviteRepository(firestore: db);

      await db.collection('invites').doc('new_schema').set({
        'inviterId': 'coach_new',
        'inviterEmail': 'coach_new@test.com',
        'inviteeEmail': 'swimmer@test.com',
        'type': 'clubInvite',
        'app': 'swimSuite',
        'createdAt': DateTime(2026, 1, 1),
        'accepted': null,
      });

      await db.collection('invites').doc('legacy_schema').set({
        'senderId': 'coach_legacy',
        'senderEmail': 'coach_legacy@test.com',
        'receiverEmail': 'swimmer@test.com',
        'type': 'seatInvite',
        'app': 'swimSuite',
        'createdAt': DateTime(2026, 1, 2),
        'accepted': null,
      });

      final invites = await repo.getInvitesByEmail('swimmer@test.com');
      final ids = invites.map((i) => i.id).toSet();

      expect(ids, {'new_schema', 'legacy_schema'});
    });

    test('de-duplicates invites that match both query fields', () async {
      final db = FakeFirebaseFirestore();
      final repo = InviteRepository(firestore: db);

      await db.collection('invites').doc('both_fields').set({
        'inviterId': 'coach',
        'inviterEmail': 'coach@test.com',
        'inviteeEmail': 'swimmer@test.com',
        'receiverEmail': 'swimmer@test.com',
        'type': 'clubInvite',
        'app': 'swimSuite',
        'createdAt': DateTime(2026, 1, 1),
        'accepted': null,
      });

      final invites = await repo.getInvitesByEmail('swimmer@test.com');

      expect(invites.length, 1);
      expect(invites.first.id, 'both_fields');
    });
  });
}
