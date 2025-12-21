import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swim_apps_shared/objects/planned/swim_groups.dart';
import 'package:swim_apps_shared/objects/swim_club.dart';

import '../../../swimify/lib/club/repository/swim_club_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late SwimClubRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = SwimClubRepository(fakeFirestore);
  });

  // ---------------------------------------------------------------------------
  // 🏊 CLUB TESTS
  // ---------------------------------------------------------------------------
  group('Club Tests', () {
    test('addClub → should add a club and return its ID', () async {
      final club = SwimClub(
        id: 'tmp',
        name: 'Wave Riders',
        creatorId: 'coach123',
        createdAt: DateTime(2024, 1, 1),
      );

      final clubId = await repository.addClub(club: club);

      expect(clubId, isNotEmpty);

      final doc = await fakeFirestore.collection('swimClubs').doc(clubId).get();

      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Wave Riders');
      expect(doc.data()?['creatorId'], 'coach123');

      // Timestamp should be stored
      expect(doc.data()?['createdAt'], isA<Timestamp>());
    });

    test('getClub → should fetch a club by its ID', () async {
      final club = SwimClub(
        id: 'tmp',
        name: 'Test Club',
        creatorId: 'coachA',
        createdAt: DateTime(2023, 5, 20),
      );

      final docRef = await fakeFirestore
          .collection('swimClubs')
          .add(club.toJson());

      final fetched = await repository.getClub(docRef.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, docRef.id);
      expect(fetched.name, 'Test Club');
      expect(fetched.createdAt, isA<DateTime>());
    });

    test('getClub → should return null for missing ID', () async {
      final fetched = await repository.getClub('does-not-exist');
      expect(fetched, isNull);
    });

    test('getClubByCreatorId → fetches the correct club', () async {
      final club = SwimClub(
        id: 'tmp',
        name: 'Sharks',
        creatorId: 'coachXYZ',
        createdAt: DateTime(2023, 5, 1),
      );

      await fakeFirestore.collection('swimClubs').add(club.toJson());

      final fetched = await repository.getClubByCreatorId('coachXYZ');

      expect(fetched, isNotNull);
      expect(fetched!.name, 'Sharks');
    });

    test('addClub → supports optional subscription fields', () async {
      final club = SwimClub(
        id: 'tmp',
        name: 'Premium Club',
        creatorId: 'coach999',
        createdAt: DateTime.now(),
        planId: 'club_large',
        isActive: true,
        endDate: DateTime.now().add(const Duration(days: 30)),
        maxGroups: 25,
        groupsCount: 3,
      );

      final clubId = await repository.addClub(club: club);
      final doc =
      await fakeFirestore.collection('swimClubs').doc(clubId).get();

      expect(doc.data()?['planId'], 'club_large');
      expect(doc.data()?['isActive'], true);
      expect(doc.data()?['maxGroups'], 25);
      expect(doc.data()?['groupsCount'], 3);
    });

    test('getClub → parses embedded groups if present', () async {
      await fakeFirestore.collection('swimClubs').add({
        'name': 'Embedded Club',
        'creatorId': 'coachX',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
        'groups': [
          {'id': 'g1', 'name': 'Group A'},
          {'id': 'g2', 'name': 'Group B'},
        ],
      });

      final snapshot = await fakeFirestore
          .collection('swimClubs')
          .where('creatorId', isEqualTo: 'coachX')
          .get();

      final fetched =
      SwimClub.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);

      expect(fetched.groups, isNotNull);
      expect(fetched.groups!.length, 2);
      expect(fetched.totalGroups, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // 👥 GROUP TESTS
  // ---------------------------------------------------------------------------
  group('Group Tests', () {
    late String testClubId;

    setUp(() async {
      final ref = await fakeFirestore.collection('swimClubs').add({
        'name': 'Test Club',
        'creatorId': 'coach123',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });
      testClubId = ref.id;
    });

    test('addGroup → should add a group to the club subcollection', () async {
      final group = SwimGroup(
        name: 'Seniors',
        coachId: 'c1',
        swimmerIds: const [],
      );

      final groupId = await repository.addGroup(testClubId, group);

      final doc = await fakeFirestore
          .collection('swimClubs')
          .doc(testClubId)
          .collection('groups')
          .doc(groupId)
          .get();

      expect(doc.exists, true);
      expect(doc.data()?['name'], 'Seniors');
    });

    test('getGroups → should return all groups for a club', () async {
      await repository.addGroup(
        testClubId,
        SwimGroup(name: 'A', coachId: 'c1', swimmerIds: const []),
      );
      await repository.addGroup(
        testClubId,
        SwimGroup(name: 'B', coachId: 'c2', swimmerIds: const []),
      );

      final groups = await repository.getGroups(testClubId);

      expect(groups.length, 2);
      expect(groups.any((g) => g.name == 'A'), true);
    });

    test('updateGroup → updates an existing group', () async {
      final group = SwimGroup(
        name: 'Old Name',
        coachId: 'c1',
        swimmerIds: const [],
      );

      final groupId = await repository.addGroup(testClubId, group);

      final updated = group.copyWith(id: groupId, name: 'New Name');

      await repository.updateGroup(testClubId, updated);

      final stored = await fakeFirestore
          .collection('swimClubs')
          .doc(testClubId)
          .collection('groups')
          .doc(groupId)
          .get();

      expect(stored.data()?['name'], 'New Name');
    });

    test('deleteGroup → removes the group from Firestore', () async {
      final groupId = await repository.addGroup(
        testClubId,
        SwimGroup(name: 'Delete Me', coachId: 'c1', swimmerIds: const []),
      );

      await repository.deleteGroup(testClubId, groupId);

      final stored = await fakeFirestore
          .collection('swimClubs')
          .doc(testClubId)
          .collection('groups')
          .doc(groupId)
          .get();

      expect(stored.exists, false);
    });
  });
}
