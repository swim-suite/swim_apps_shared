import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:swim_apps_shared/auth_service.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_service.dart';
import 'package:swim_apps_shared/objects/user/swimmer.dart';
import 'package:swim_apps_shared/repositories/invite_repository.dart';
import 'package:swim_apps_shared/repositories/user_repository.dart';

import '../../../mocks.mocks.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late MockFirebaseFunctions functions;
  late MockUser inviter;
  late UserRepository userRepository;
  late InviteService inviteService;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    functions = MockFirebaseFunctions();
    inviter = MockUser();

    when(auth.currentUser).thenReturn(inviter);
    when(inviter.uid).thenReturn('inviter_uid');
    when(inviter.email).thenReturn('coach@example.com');
    when(inviter.displayName).thenReturn('Coach Example');

    userRepository = UserRepository(
      db,
      authService: AuthService(firebaseAuth: auth),
    );

    inviteService = InviteService(
      inviteRepository: InviteRepository(firestore: db),
      auth: auth,
      firestore: db,
      functions: functions,
      userRepository: userRepository,
    );
  });

  group('InviteService.invite', () {
    test('invite new email creates alias + alias membership', () async {
      final result = await inviteService.invite(
        email: ' New.Invited@Example.com ',
        name: 'New Invited',
        context: const InviteMembershipContext(
          contextType: 'club',
          contextId: 'club_1',
          role: 'coach',
        ),
        sendEmail: false,
      );

      expect(result.isAliasPrincipal, isTrue);
      expect(result.aliasId, isNotNull);

      final aliasDoc = await db.collection('aliases').doc(result.aliasId).get();
      final membershipDoc =
          await db.collection('memberships').doc(result.membershipId).get();

      expect(aliasDoc.exists, isTrue);
      expect(aliasDoc.data()?['email'], 'new.invited@example.com');
      expect(aliasDoc.data()?['userId'], isNull);

      expect(membershipDoc.exists, isTrue);
      expect(membershipDoc.data()?['aliasId'], result.aliasId);
      expect(membershipDoc.data()?['userId'], isNull);
      expect(membershipDoc.data()?['resolvedUserId'], isNull);
    });

    test('invite existing user email creates membership by userId', () async {
      await db.collection('users').doc('existing_uid').set({
        'id': 'existing_uid',
        'email': 'existing@example.com',
        'emailNormalized': 'existing@example.com',
        'name': 'Existing User',
      });

      final result = await inviteService.invite(
        email: 'existing@example.com',
        name: 'Existing User',
        context: const InviteMembershipContext(
          contextType: 'team',
          contextId: 'team_1',
          role: 'swimmer',
        ),
        sendEmail: false,
      );

      expect(result.isAliasPrincipal, isFalse);
      expect(result.aliasId, isNull);

      final membershipDoc =
          await db.collection('memberships').doc(result.membershipId).get();
      expect(membershipDoc.exists, isTrue);
      expect(membershipDoc.data()?['aliasId'], isNull);
      expect(membershipDoc.data()?['userId'], 'existing_uid');
      expect(membershipDoc.data()?['resolvedUserId'], 'existing_uid');
    });

    test('re-invite same email/context is idempotent (no duplicate membership)',
        () async {
      final first = await inviteService.invite(
        email: 'same@example.com',
        name: 'Same User',
        context: const InviteMembershipContext(
          contextType: 'club',
          contextId: 'club_1',
          role: 'coach',
        ),
        sendEmail: false,
      );

      final second = await inviteService.invite(
        email: 'same@example.com',
        name: 'Same User',
        context: const InviteMembershipContext(
          contextType: 'club',
          contextId: 'club_1',
          role: 'coach',
        ),
        sendEmail: false,
      );

      final memberships = await db
          .collection('memberships')
          .where('contextType', isEqualTo: 'club')
          .where('contextId', isEqualTo: 'club_1')
          .get();

      expect(first.membershipId, second.membershipId);
      expect(memberships.docs.length, 1);
    });
  });

  group('UserRepository.createOrMergeUserByEmail', () {
    test(
        'signup with alias present links alias.userId and resolves memberships',
        () async {
      await db.collection('aliases').doc('alias_signup').set({
        'email': 'invitee@example.com',
        'userId': null,
      });
      await db.collection('memberships').doc('membership_signup').set({
        'aliasId': 'alias_signup',
        'contextType': 'club',
        'contextId': 'club_2',
        'role': 'coach',
      });

      final newUser = Swimmer(
        id: 'uid_signup',
        name: 'Invitee',
        email: 'Invitee@Example.com',
      );

      await userRepository.createOrMergeUserByEmail(newUser: newUser);

      final aliasDoc = await db.collection('aliases').doc('alias_signup').get();
      final membership =
          await db.collection('memberships').doc('membership_signup').get();
      final userDoc = await db.collection('users').doc('uid_signup').get();

      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['emailNormalized'], 'invitee@example.com');
      expect(aliasDoc.data()?['userId'], 'uid_signup');
      expect(membership.data()?['resolvedUserId'], 'uid_signup');
      expect(membership.data()?['userId'], 'uid_signup');
    });

    test('simulated concurrent signups keep a single alias.userId winner',
        () async {
      await db.collection('aliases').doc('alias_concurrent').set({
        'email': 'race@example.com',
        'userId': null,
      });

      final first = userRepository.createOrMergeUserByEmail(
        newUser: Swimmer(
            id: 'uid_race_a', name: 'Race A', email: 'race@example.com'),
      );
      final second = userRepository.createOrMergeUserByEmail(
        newUser: Swimmer(
            id: 'uid_race_b', name: 'Race B', email: 'race@example.com'),
      );

      await Future.wait<void>([
        first,
        second.catchError((_) => null),
      ]);

      final aliasDoc =
          await db.collection('aliases').doc('alias_concurrent').get();
      final winner = aliasDoc.data()?['userId'] as String?;

      expect(winner, isNotNull);
      expect({'uid_race_a', 'uid_race_b'}.contains(winner), isTrue);
    });
  });

  test('integration: invite -> signup -> membership resolution', () async {
    final inviteResult = await inviteService.invite(
      email: 'flow@example.com',
      name: 'Flow User',
      context: const InviteMembershipContext(
        contextType: 'club',
        contextId: 'club_flow',
        role: 'coach',
      ),
      sendEmail: false,
    );

    await userRepository.createOrMergeUserByEmail(
      newUser: Swimmer(
        id: 'uid_flow',
        name: 'Flow User',
        email: 'flow@example.com',
      ),
    );

    final aliasDoc =
        await db.collection('aliases').doc(inviteResult.aliasId).get();
    final membershipDoc =
        await db.collection('memberships').doc(inviteResult.membershipId).get();

    expect(aliasDoc.data()?['userId'], 'uid_flow');
    expect(membershipDoc.data()?['resolvedUserId'], 'uid_flow');
    expect(membershipDoc.data()?['userId'], 'uid_flow');
  });
}
