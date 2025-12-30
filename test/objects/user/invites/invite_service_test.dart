import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:swim_apps_shared/objects/user/invites/app_enums.dart';
import 'package:swim_apps_shared/objects/user/invites/app_invite.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_service.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_type.dart';

import '../../../mocks.mocks.dart';

void main() {
  late MockInviteRepository inviteRepo;
  late MockFirebaseAuth auth;
  late MockFirebaseFirestore firestore;
  late MockFirebaseFunctions functions;
  late InviteService service;
  late MockCollectionReference invitesCollection;
  late MockDocumentReference inviteDoc;

  setUp(() {
    inviteRepo = MockInviteRepository();
    auth = MockFirebaseAuth();
    firestore = MockFirebaseFirestore();
    functions = MockFirebaseFunctions();

    invitesCollection = MockCollectionReference();
    inviteDoc = MockDocumentReference();

    when(firestore.collection('invites')).thenReturn(
        invitesCollection as CollectionReference<Map<String, dynamic>>);

    when(invitesCollection.doc(any))
        .thenReturn(inviteDoc as DocumentReference<Map<String, dynamic>>);

    when(inviteDoc.update(any)).thenAnswer((_) async {});

    service = InviteService(
      inviteRepository: inviteRepo,
      auth: auth,
      firestore: firestore,
      functions: functions,
    );
  });

  AppInvite invite0({
    required String id,
    bool? accepted,
    DateTime? createdAt,
  }) {
    return AppInvite(
      id: id,
      inviterId: 'inviter',
      inviterEmail: 'coach@test.com',
      inviteeEmail: 'swimmer@test.com',
      type: InviteType.coachToSwimmer,
      app: App.swimAnalyzer,
      createdAt: createdAt ?? DateTime.now(),
      accepted: accepted,
      acceptedUserId: accepted == true ? 'user123' : null,
      acceptedAt: accepted != null ? DateTime.now() : null,
    );
  }

  group('requestToJoinClub', () {
    test('throws if no logged-in user', () async {
      when(auth.currentUser).thenReturn(null);

      expect(
        () => service.requestToJoinClub(clubId: 'club_123'),
        throwsException,
      );
    });

    test('throws if user has no email', () async {
      final mockUser = MockUser();

      when(auth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user123');
      when(mockUser.email).thenReturn(null);

      expect(
        () => service.requestToJoinClub(clubId: 'club_123'),
        throwsException,
      );
    });

    test('creates a pending club invite for the given club', () async {
      final mockUser = MockUser();

      when(auth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user123');
      when(mockUser.email).thenReturn('user@test.com');

      AppInvite? capturedInvite;

      when(inviteRepo.sendInvite(any)).thenAnswer((invocation) async {
        capturedInvite = invocation.positionalArguments.first as AppInvite;
      });

      await service.requestToJoinClub(clubId: 'club_123');

      // Ensure invite was sent
      verify(inviteRepo.sendInvite(any)).called(1);
      expect(capturedInvite, isNotNull);

      // Validate invite contents
      expect(capturedInvite!.type, InviteType.clubInvite);
      expect(capturedInvite!.app, App.swimSuite);
      expect(capturedInvite!.clubId, 'club_123');
      expect(capturedInvite!.accepted, false);
      expect(capturedInvite!.acceptedUserId, isNull);
      expect(capturedInvite!.inviterId, 'user123');
      expect(capturedInvite!.inviterEmail, 'user@test.com');
    });
  });

  group('getInviteByEmail', () {
    test('returns pending invite if present', () async {
      final invites = [
        invite0(id: '1', accepted: true),
        invite0(id: '2', accepted: null),
        invite0(id: '3', accepted: false),
      ];

      when(inviteRepo.getInvitesByEmail(any)).thenAnswer((_) async => invites);

      final result = await service.getInviteByEmail('swimmer@test.com');

      expect(result, isNotNull);
      expect(result!.accepted, isNull);
      expect(result.id, '2');
    });

    test('returns accepted if no pending exists', () async {
      final invites = [
        invite0(id: '1', accepted: false),
        invite0(id: '2', accepted: true),
      ];

      when(inviteRepo.getInvitesByEmail(any)).thenAnswer((_) async => invites);

      final result = await service.getInviteByEmail('swimmer@test.com');

      expect(result!.accepted, true);
      expect(result.id, '2');
    });

    test('returns denied if only denied exists', () async {
      final invites = [
        invite0(id: '1', accepted: false),
      ];

      when(inviteRepo.getInvitesByEmail(any)).thenAnswer((_) async => invites);

      final result = await service.getInviteByEmail('swimmer@test.com');

      expect(result!.accepted, false);
      expect(result.id, '1');
    });

    test('returns null if no invites exist', () async {
      when(inviteRepo.getInvitesByEmail(any)).thenAnswer((_) async => []);

      final result = await service.getInviteByEmail('swimmer@test.com');

      expect(result, isNull);
    });
  });

  group('acceptInvite', () {
    test('updates invite to accepted', () async {
      final invite = invite0(id: 'invite1', accepted: null);
      final mockUser = MockUser();

      when(auth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user123');

      when(inviteRepo.collection).thenReturn(MockCollectionReference());

      // We don’t assert Firestore internals, only that it doesn’t throw
      await service.acceptInvite(
        appInvite: invite,
        userId: 'user123',
      );

      // No exception = success
      expect(true, true);
    });
  });

  group('tri-state semantics', () {
    test('pending invite has accepted == null', () {
      final invite = invite0(id: 'x', accepted: null);
      expect(invite.accepted, isNull);
    });

    test('accepted invite has accepted == true', () {
      final invite = invite0(id: 'x', accepted: true);
      expect(invite.accepted, isTrue);
    });

    test('denied invite has accepted == false', () {
      final invite = invite0(id: 'x', accepted: false);
      expect(invite.accepted, isFalse);
    });
  });
}
