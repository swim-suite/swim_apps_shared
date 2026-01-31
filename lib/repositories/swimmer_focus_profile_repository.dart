import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../objects/user/swimmer_focus_profile.dart';

class SwimmerFocusProfileRepository {
  final FirebaseFirestore _db;
  final String clubId;

  SwimmerFocusProfileRepository(
    this._db, {
    required this.clubId,
  });

  /// /swimClubs/{clubId}/swimmerFocusProfile
  CollectionReference<SwimmerFocusProfile> get _profilesCollection => _db
      .collection('swimClubs')
      .doc(clubId)
      .collection('swimmerFocusProfile')
      .withConverter<SwimmerFocusProfile>(
        fromFirestore: (snapshot, _) {
          final data = snapshot.data();
          if (data == null) {
            throw Exception(
              'Document ${snapshot.id} has null data and cannot be parsed.',
            );
          }
          return SwimmerFocusProfile.fromJson(data);
        },
        toFirestore: (profile, _) => profile.toJson(),
      );

  // --------------------------------------------------------------------------
  // WRITE
  // --------------------------------------------------------------------------

  /// Create or update a swimmer focus profile (upsert).
  Future<void> saveProfile(SwimmerFocusProfile profile) async {
    try {
      await _profilesCollection
          .doc(profile.id)
          .set(profile, SetOptions(merge: true));
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Error saving swimmer focus profile ${profile.id}: $e\n$s',
      );
      rethrow;
    }
  }

  /// Delete a focus profile by document id.
  Future<void> deleteProfile(String profileId) async {
    try {
      await _profilesCollection.doc(profileId).delete();
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Error deleting swimmer focus profile $profileId: $e\n$s',
      );
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // READ (club-scoped)
  // --------------------------------------------------------------------------

  /// ✅ Preferred: get focus profile for a specific swimmer in this club.
  ///
  /// There should be at most ONE profile per swimmer per club.
  Future<SwimmerFocusProfile?> getProfileForSwimmer(String swimmerId) async {
    try {
      final snapshot = await _profilesCollection
          .where('swimmerId', isEqualTo: swimmerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Error fetching focus profile for swimmer $swimmerId: $e\n$s',
      );
      rethrow;
    }
  }

  /// 🔄 Reactive version for UI
  Stream<SwimmerFocusProfile?> streamProfileForSwimmer(String swimmerId) {
    return _profilesCollection
        .where('swimmerId', isEqualTo: swimmerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    });
  }

  /// (Optional) Fetch all focus profiles in the club
  /// Useful for dashboards / analytics.
  Future<List<SwimmerFocusProfile>> getAllProfilesInClub() async {
    try {
      final snapshot = await _profilesCollection.get();
      return _parseProfiles(snapshot.docs);
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Error fetching all swimmer focus profiles for club $clubId: $e\n$s',
      );
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  List<SwimmerFocusProfile> _parseProfiles(
    List<QueryDocumentSnapshot<SwimmerFocusProfile>> docs,
  ) {
    final List<SwimmerFocusProfile> profiles = [];

    for (final doc in docs) {
      try {
        profiles.add(doc.data());
      } catch (e, s) {
        debugPrint(
          '⚠️ Failed to parse swimmer focus profile ${doc.id}: $e\n$s',
        );
      }
    }

    return profiles;
  }
}
