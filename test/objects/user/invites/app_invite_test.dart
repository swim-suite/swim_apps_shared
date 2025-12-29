import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:swim_apps_shared/objects/user/coach.dart';
import 'package:swim_apps_shared/objects/user/invites/app_enums.dart';
import 'package:swim_apps_shared/objects/user/invites/app_invite.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_type.dart';

import '../../../mocks.mocks.dart';

void main() {
  group('AppInvite.fromJson', () {
    test('parses full valid json correctly', () {
      final now = DateTime.now();

      final invite = AppInvite.fromJson('invite1', {
        'inviterId': 'coach1',
        'inviterEmail': 'coach@test.com',
        'inviteeEmail': 'swimmer@test.com',
        'type': InviteType.coachToSwimmer.name,
        'app': App.swimAnalyzer.name,
        'createdAt': Timestamp.fromDate(now),
        'accepted': true,
        'acceptedUserId': 'swimmer1',
        'clubId': 'club1',
        'relatedEntityId': 'group1',
        'acceptedAt': now.toIso8601String(),
      });

      expect(invite.id, 'invite1');
      expect(invite.inviterId, 'coach1');
      expect(invite.inviterEmail, 'coach@test.com');
      expect(invite.inviteeEmail, 'swimmer@test.com');
      expect(invite.type, InviteType.coachToSwimmer);
      expect(invite.app, App.swimAnalyzer);
      expect(invite.accepted, true);
      expect(invite.acceptedUserId, 'swimmer1');
      expect(invite.clubId, 'club1');
      expect(invite.relatedEntityId, 'group1');
      expect(invite.acceptedAt, isNotNull);
    });

    test('falls back to defaults on unknown enum values', () {
      final invite = AppInvite.fromJson('invite2', {
        'inviterId': 'x',
        'inviteeEmail': 'y@test.com',
        'type': 'unknown',
        'app': 'unknown',
        'createdAt': 0,
      });

      expect(invite.type, InviteType.coachToSwimmer);
      expect(invite.app, App.swimAnalyzer);
    });
  });

  group('AppInvite.toJson', () {
    test('serializes fields correctly', () {
      final invite = _invite(accepted: null);

      final json = invite.toJson();

      expect(json['inviterId'], invite.inviterId);
      expect(json['inviteeEmail'], invite.inviteeEmail);
      expect(json['type'], invite.type.name);
      expect(json['app'], invite.app.name);
      expect(json['accepted'], null);
    });
  });

  group('AppInvite.copyWith', () {
    test('overrides only provided fields', () {
      final original = _invite(accepted: null);

      final updated = original.copyWith(
        accepted: true,
        acceptedUserId: 'user2',
      );

      expect(updated.id, original.id);
      expect(updated.accepted, true);
      expect(updated.acceptedUserId, 'user2');
      expect(updated.inviterId, original.inviterId);
    });
  });

  group('AppInviteStatus extension', () {
    test('pending when accepted == null', () {
      final invite = _invite(accepted: null);
      expect(invite.isPending, true);
      expect(invite.isAccepted, false);
      expect(invite.isDenied, false);
    });

    test('accepted when accepted == true', () {
      final invite = _invite(accepted: true);
      expect(invite.isAccepted, true);
      expect(invite.isPending, false);
      expect(invite.isDenied, false);
    });

    test('denied when accepted == false', () {
      final invite = _invite(accepted: false);
      expect(invite.isDenied, true);
      expect(invite.isPending, false);
      expect(invite.isAccepted, false);
    });
  });

  group('AppInvite.otherPartyUser', () {
    late MockUserRepository userRepo;

    setUp(() {
      userRepo = MockUserRepository();
    });

    test('returns accepted user when current user is inviter', () async {
      final invite = _invite(
        inviterId: 'coach1',
        acceptedUserId: 'swimmer1',
        accepted: true,
      );

      final coach = _coach('swimmer1');

      when(userRepo.getUserDocument('swimmer1')).thenAnswer((_) async => coach);

      final result = await invite.otherPartyUser(
        currentUserId: 'coach1',
        userRepo: userRepo,
      );

      expect(result, coach);
      verify(userRepo.getUserDocument('swimmer1')).called(1);
    });

    test('returns inviter when current user is accepted user', () async {
      final invite = _invite(
        inviterId: 'coach1',
        acceptedUserId: 'swimmer1',
        accepted: true,
      );

      final coach = _coach('coach1');

      when(userRepo.getUserDocument('coach1')).thenAnswer((_) async => coach);

      final result = await invite.otherPartyUser(
        currentUserId: 'swimmer1',
        userRepo: userRepo,
      );

      expect(result, coach);
      verify(userRepo.getUserDocument('coach1')).called(1);
    });

    test('returns null if other party cannot be resolved', () async {
      final invite = _invite(
        inviterId: 'coach1',
        acceptedUserId: null,
        accepted: null,
      );

      final result = await invite.otherPartyUser(
        currentUserId: 'coach1',
        userRepo: userRepo,
      );

      expect(result, isNull);
      verifyNever(userRepo.getUserDocument(any));
    });
  });
}

/// ---------------------------------------------------------------------------
/// Helpers
/// ---------------------------------------------------------------------------

AppInvite _invite({
  String id = 'invite1',
  String inviterId = 'coach1',
  String inviterEmail = 'coach@test.com',
  String inviteeEmail = 'swimmer@test.com',
  InviteType type = InviteType.coachToSwimmer,
  App app = App.swimAnalyzer,
  bool? accepted,
  String? acceptedUserId,
}) {
  return AppInvite(
    id: id,
    inviterId: inviterId,
    inviterEmail: inviterEmail,
    inviteeEmail: inviteeEmail,
    type: type,
    app: app,
    createdAt: DateTime.now(),
    accepted: accepted,
    acceptedUserId: acceptedUserId,
  );
}

Coach _coach(String id) {
  return Coach(
    id: id,
    name: 'Coach $id',
    email: '$id@test.com',
  );
}
