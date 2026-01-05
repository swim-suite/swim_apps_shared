import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../objects/user/swimmer_focus_profile.dart';

/// A repository for managing swimmer focus profiles in Firestore.
///
/// 🔐 Club-scoped:
/// Data is stored under:
/// /swimClubs/{clubId}/swimmerFocusProfile/{profileId}
///
/// This aligns exactly with Firestore security rules.
class SwimmerFocusProfileRepository {
  final FirebaseFirestore _db;
  final String clubId;

  /// The repository is explicitly bound to a club.
  ///
  /// This avoids permission issues and makes the data model explicit.
  SwimmerFocusProfileRepository(
      this._db, {
        required this.clubId,
      });

  /// Typed reference to:
  /// /swimClubs/{clubId}/swimmerFocusProfile
  CollectionReference<SwimmerFocusProfile> get _profilesCollection =>
      _db
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

  /// Saves or updates a swimmer focus profile.
  ///
  /// Uses merge to support upserts.
  Future<void> saveProfile(SwimmerFocusProfile profile) async {
    try {
      await _profilesCollection
          .doc(profile.id)
          .set(profile, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint(
        '🔥 Firestore Error saving focus profile ${profile.id}: $e',
      );
      rethrow;
    }
  }

  /// Retrieves all focus profiles owned by a coach.
  ///
  /// Rule-aligned query:
  /// request.query.where.coachId == request.auth.uid
  Future<List<SwimmerFocusProfile>> getProfilesForCoach(
      String coachId,
      ) async {
    try {
      final snapshot = await _profilesCollection
          .where('coachId', isEqualTo: coachId)
          .get();

      return _parseProfilesFromSnapshot(snapshot.docs);
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Firestore Error fetching profiles for coach $coachId: $e\n$s',
      );
      return [];
    }
  }

  /// Retrieves a single focus profile by its document ID.
  ///
  /// Returns null if it does not exist.
  Future<SwimmerFocusProfile?> getProfile(String profileId) async {
    try {
      final doc = await _profilesCollection.doc(profileId).get();
      return doc.data();
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Firestore Error fetching focus profile $profileId: $e\n$s',
      );
      rethrow;
    }
  }

  /// Deletes a focus profile.
  Future<void> deleteProfile(String profileId) async {
    try {
      await _profilesCollection.doc(profileId).delete();
    } on FirebaseException catch (e, s) {
      debugPrint(
        '🔥 Firestore Error deleting focus profile $profileId: $e\n$s',
      );
      rethrow;
    }
  }

  /// Safely parses query snapshots.
  ///
  /// Individual corrupt documents are skipped instead of crashing the app.
  List<SwimmerFocusProfile> _parseProfilesFromSnapshot(
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
