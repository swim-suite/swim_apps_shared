import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/objects/planned/swim_groups.dart';
import 'package:swim_apps_shared/objects/swim_club.dart';

/// Repository for all club-related Firestore operations.
/// Fully aligned with the new club-centric Firestore rules.
class SwimClubRepository {
  final FirebaseFirestore _db;

  SwimClubRepository(FirebaseFirestore firestore) : _db = firestore;

  CollectionReference<Map<String, dynamic>> get _clubs =>
      _db.collection('swimClubs');

  // ---------------------------------------------------------------------------
  // 🏊 CLUB CRUD
  // ---------------------------------------------------------------------------

  /// ➕ Creates a new swim club.
  Future<String> addClub({required SwimClub club}) async {
    try {
      final doc = await _clubs.add(club.toJson());
      return doc.id;
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore error adding club: ${e.message}');
      rethrow;
    }
  }

  /// 🔹 Reads a single club by ID.
  Future<SwimClub?> getClub(String clubId) async {
    if (clubId.isEmpty) return null;

    try {
      final doc = await _clubs.doc(clubId).get();

      if (!doc.exists) return null;

      return SwimClub.fromJson(doc.data()!, doc.id);
    } catch (e, s) {
      debugPrint('❌ Error loading club $clubId: $e\n$s');
      rethrow;
    }
  }

  /// 🔍 Finds the club created by a specific coach.
  Future<SwimClub?> getClubByCreatorId(String coachId) async {
    if (coachId.isEmpty) return null;

    try {
      final query =
          await _clubs.where('creatorId', isEqualTo: coachId).limit(1).get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;

      return SwimClub.fromJson(doc.data(), doc.id);
    } catch (e, s) {
      debugPrint('❌ Error fetching club by creatorId: $e\n$s');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 👥 MEMBERSHIP MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Adds a swimmer to a club's swimmers list.
  Future<void> addSwimmerToClub(String clubId, String swimmerId) async {
    try {
      await _clubs
          .doc(clubId)
          .collection('swimmers')
          .doc(swimmerId)
          .set({'joinedAt': FieldValue.serverTimestamp()});
    } catch (e, s) {
      debugPrint('❌ Error adding swimmer: $e\n$s');
      rethrow;
    }
  }

  /// Adds a coach to a club.
  Future<void> addCoachToClub(String clubId, String coachId) async {
    try {
      await _clubs
          .doc(clubId)
          .collection('coaches')
          .doc(coachId)
          .set({'joinedAt': FieldValue.serverTimestamp()});
    } catch (e, s) {
      debugPrint('❌ Error adding coach: $e\n$s');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 🏊 GROUP MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<List<SwimGroup>> getGroups(String? clubId) async {
    if (clubId == null || clubId.isEmpty) return [];

    try {
      final snap = await _clubs.doc(clubId).collection('groups').get();

      return snap.docs
          .map((doc) => SwimGroup.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e, s) {
      debugPrint("❌ Error fetching groups: $e\n$s");
      rethrow;
    }
  }

  Future<String> addGroup(String clubId, SwimGroup group) async {
    if (clubId.isEmpty) throw ArgumentError('Club ID cannot be empty');

    try {
      final data = group.toJson()..remove('id');
      final ref = await _clubs.doc(clubId).collection('groups').add(data);
      return ref.id;
    } catch (e, s) {
      debugPrint('❌ Error adding group: $e\n$s');
      rethrow;
    }
  }

  Future<void> updateGroup(String clubId, SwimGroup group) async {
    if (clubId.isEmpty || group.id == null) return;

    try {
      await _clubs
          .doc(clubId)
          .collection('groups')
          .doc(group.id)
          .update(group.toJson());
    } catch (e, s) {
      debugPrint('❌ Error updating group: $e\n$s');
      rethrow;
    }
  }

  Future<void> deleteGroup(String clubId, String groupId) async {
    if (clubId.isEmpty || groupId.isEmpty) return;

    try {
      await _clubs.doc(clubId).collection('groups').doc(groupId).delete();
    } catch (e, s) {
      debugPrint('❌ Error deleting group: $e\n$s');
      rethrow;
    }
  }

// ---------------------------------------------------------------------------
// 🚫 REMOVED: Global invites (not allowed by your rules)
// ---------------------------------------------------------------------------

  /// ❌ Removed: Old global `invites` collection no longer fits the new rules.
  /// Club invites should live under:
  ///   swimClubs/{clubId}/invites/{inviteId}
  ///
  /// If needed, I can implement this new path.
}
