import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

// Removed: Firebase Crashlytics import is no longer needed.
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../auth_service.dart';
import '../objects/user/swimmer.dart';
import '../objects/user/user.dart';
import '../objects/user/user_types.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository {
  final FirebaseFirestore _db;
  final AuthService _authService;

  // --- Refactoring for Simplicity ---
  // The constructor is simplified to only require essential dependencies (_db and _authService).
  // The optional FirebaseCrashlytics parameter and the private _crashlytics field are removed.
  UserRepository(this._db, {required AuthService authService})
      : _authService = authService;

  static const List<String> _membershipCollections = <String>[
    'memberships',
    'club_memberships',
    'team_memberships',
    'seat_memberships',
  ];

  CollectionReference get usersCollection => _db.collection('users');

  CollectionReference get _coachesCollection => _db.collection('coaches');

  CollectionReference<Map<String, dynamic>> get _aliasesCollection =>
      _db.collection('aliases');

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _stableDocId(String source) =>
      base64Url.encode(utf8.encode(source)).replaceAll('=', '');

  String _aliasIdForEmail(String normalizedEmail) =>
      _stableDocId('alias:$normalizedEmail');

  /// Helper function to map a QuerySnapshot to a list of AppUser objects.
  /// This reduces code duplication in stream-based methods and isolates parsing logic.
  List<AppUser> _mapSnapshotToUsers(QuerySnapshot snapshot) {
    final users = <AppUser>[];
    for (final doc in snapshot.docs) {
      try {
        // Use a safe parsing helper to handle potential data corruption.
        final user = _parseUserDoc(doc);
        if (user != null) {
          users.add(user);
        }
      } catch (e, s) {
        // --- Error Handling Improvement ---
        // Instead of logging to Crashlytics, a detailed error is printed to the
        // debug console. This helps identify data integrity issues during development.
        final errorMessage = "Error parsing user ${doc.id} in a stream: $e";
        debugPrint(errorMessage);
        debugPrintStack(stackTrace: s);
      }
    }
    return users;
  }

  /// Safely parses a DocumentSnapshot into an AppUser.
  /// Returns null if the data is invalid, and prints a warning.
  AppUser? _parseUserDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) {
      // --- Error Handling Improvement ---
      // Invalid data type is a data integrity issue. We log it to the console
      // and return null to prevent a crash.
      final errorMessage =
          "⚠️ Skipped user ${doc.id} — data type ${raw.runtimeType} is not a Map.";
      debugPrint(errorMessage);
      return null;
    }
    // The fromJson method could still throw if fields are missing/wrong type.
    // This is caught by the calling function's try-catch block.
    return AppUser.fromJson(doc.id, raw);
  }

  // --- STREAM: Current User Profile ---
  Stream<AppUser?> myProfileStream() {
    return _authService.authStateChanges.asyncMap((user) {
      if (user != null) {
        return getUserDocument(user.uid);
      } else {
        return null;
      }
    });
  }

  // --- STREAM: Users by Club ---
  Stream<List<AppUser>> getUsersByClub(String clubId) {
    return usersCollection
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(_mapSnapshotToUsers)
        .handleError((error, stackTrace) {
      // Catch and log errors from the stream itself (e.g., permission denied).
      debugPrint("🔥 Error in getUsersByClub stream: $error");
      // Return an empty list to keep the stream alive and the UI stable.
      return <AppUser>[];
    });
  }

  // --- STREAM: Users created by me ---
  Stream<List<AppUser>> getUsersCreatedByMe() {
    final myId = _authService.currentUserId;
    if (myId == null) return Stream.value([]);

    return usersCollection
        .where('coachCreatorId', isEqualTo: myId)
        .snapshots()
        .map(_mapSnapshotToUsers)
        .handleError((error, stackTrace) {
      // Catch and log errors from the stream itself.
      debugPrint("🔥 Error in getUsersCreatedByMe stream: $error");
      return <AppUser>[];
    });
  }

  // --- CREATE: Swimmer ---
  Future<Swimmer> createSwimmer({
    String? clubId,
    String? lastName,
    required String name,
    required String email,
  }) async {
    final newDocRef = usersCollection.doc();
    final newSwimmer = Swimmer(
      id: newDocRef.id,
      name: name,
      email: email,
      registerDate: DateTime.now(),
      updatedAt: DateTime.now(),
      creatorId: _authService.currentUserId,
      clubId: clubId,
      lastName: lastName,
    )..userType = UserType.swimmer;

    try {
      await newDocRef.set(newSwimmer.toJson());
      return newSwimmer;
    } catch (e) {
      debugPrint("🔥 Error creating swimmer document: $e");
      // This is a critical failure, so we rethrow to let the caller handle it (e.g., show a dialog).
      throw Exception("Failed to create swimmer: $e");
    }
  }

  // --- UPDATE: Profile ---
  Future<void> updateMyProfile({required AppUser appUser}) async {
    try {
      await usersCollection.doc(appUser.id).update(appUser.toJson());
    } catch (e) {
      debugPrint("🔥 Error updating user profile ${appUser.id}: $e");
      // Rethrow to allow the UI to show an error message.
      throw Exception("Failed to update profile: $e");
    }
  }

  // --- GET: Single User ---
  Future<AppUser?> getUserDocument(String uid) async {
    if (uid.isEmpty) {
      debugPrint("⚠️ Error: UID cannot be empty when fetching user document.");
      return null;
    }

    try {
      final DocumentSnapshot userDoc = await usersCollection.doc(uid).get();

      if (!userDoc.exists) {
        debugPrint("No user document found for UID: $uid");
        return null;
      }
      return _parseUserDoc(userDoc);
    } catch (e) {
      debugPrint("🔥 Error fetching user document for UID $uid: $e");
      // Return null to indicate failure without crashing.
      return null;
    }
  }

  // --- GET: Batch by IDs ---
  Future<List<AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final users = <AppUser>[];
      // Firestore 'whereIn' queries are limited to 30 elements. Batching handles larger lists.
      for (var i = 0; i < userIds.length; i += 30) {
        final chunk = userIds.sublist(
          i,
          i + 30 > userIds.length ? userIds.length : i + 30,
        );
        final QuerySnapshot snapshot = await usersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          try {
            final user = _parseUserDoc(doc);
            if (user != null) {
              users.add(user);
            }
          } catch (e, s) {
            final errorMessage = "Error parsing user ${doc.id} in batch: $e";
            debugPrint(errorMessage);
            debugPrintStack(stackTrace: s);
          }
        }
      }
      return users;
    } catch (e) {
      debugPrint("🔥 Error fetching users by IDs: $e");
      return [];
    }
  }

  // --- GET: All swimmers created by coach ---
  Future<List<Swimmer>> getAllSwimmersFromCoach({
    required String coachId,
  }) async {
    try {
      final QuerySnapshot snapshot = await usersCollection
          .where('userType', isEqualTo: UserType.swimmer.name)
          .where('coachCreatorId', isEqualTo: coachId)
          .orderBy('name')
          .get();

      final swimmers = <Swimmer>[];
      for (final doc in snapshot.docs) {
        final raw = doc.data();
        if (raw is! Map<String, dynamic>) {
          debugPrint(
            "⚠️ Skipped swimmer ${doc.id} — data type ${raw.runtimeType}.",
          );
          continue;
        }
        try {
          swimmers.add(Swimmer.fromJson(doc.id, raw));
        } catch (e, s) {
          final errorMessage = "Error parsing swimmer ${doc.id}: $e";
          debugPrint(errorMessage);
          debugPrintStack(stackTrace: s);
        }
      }
      return swimmers;
    } catch (e) {
      debugPrint("🔥 Error fetching swimmers from coach: $e");
      return [];
    }
  }

  // --- CREATE / UPDATE ---
  /// Attempts to resolve the alias principal for the given email and lock it for updates.
  ///
  /// Dart transactions can only lock document refs (`tx.get(docRef)`), not queries.
  /// We therefore query aliases by email and then lock the chosen doc in the same
  /// transaction with `tx.get(reference)`.
  Future<DocumentReference<Map<String, dynamic>>?>
      resolveAliasForEmailForUpdate({
    required Transaction tx,
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final deterministicAliasRef =
        _aliasesCollection.doc(_aliasIdForEmail(normalizedEmail));
    final deterministicAliasSnap = await tx.get(deterministicAliasRef);
    if (deterministicAliasSnap.exists) {
      return deterministicAliasRef;
    }

    final aliasByEmail = await _aliasesCollection
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (aliasByEmail.docs.isEmpty) {
      return null;
    }

    final aliasRef = aliasByEmail.docs.first.reference;
    final lockedAliasSnap = await tx.get(aliasRef);
    if (!lockedAliasSnap.exists) return null;
    return aliasRef;
  }

  Future<Set<String>> _candidateAliasIdsForEmail(String normalizedEmail) async {
    final aliasIds = <String>{_aliasIdForEmail(normalizedEmail)};

    final legacyAliasQuery = await _aliasesCollection
        .where('email', isEqualTo: normalizedEmail)
        .limit(10)
        .get();
    for (final doc in legacyAliasQuery.docs) {
      aliasIds.add(doc.id);
    }
    return aliasIds;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>>
      _prefetchMembershipRefsForAliases({
    required Iterable<String> aliasIds,
    int perCollectionLimit = 25,
  }) async {
    final refsByPath = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final aliasId in aliasIds) {
      for (final collection in _membershipCollections) {
        final query = await _db
            .collection(collection)
            .where('aliasId', isEqualTo: aliasId)
            .limit(perCollectionLimit)
            .get();
        for (final doc in query.docs) {
          refsByPath[doc.reference.path] = doc.reference;
        }
      }
    }
    return refsByPath.values.toList();
  }

  Future<int> _syncMembershipsForAliases({
    required Iterable<String> aliasIds,
    required String userId,
  }) async {
    var updated = 0;
    final deduped = aliasIds.toSet();
    for (final aliasId in deduped) {
      updated +=
          await syncMembershipsForAlias(aliasId: aliasId, userId: userId);
    }
    return updated;
  }

  /// Updates memberships in pages to avoid transaction size limits.
  ///
  /// This method is idempotent: docs already resolved to [userId] are skipped.
  Future<int> syncMembershipsForAlias({
    required String aliasId,
    required String userId,
    int pageSize = 200,
  }) async {
    var updatedCount = 0;

    for (final collection in _membershipCollections) {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query = _db
            .collection(collection)
            .where('aliasId', isEqualTo: aliasId)
            .orderBy(FieldPath.documentId)
            .limit(pageSize);

        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }

        final page = await query.get();
        if (page.docs.isEmpty) break;

        final batch = _db.batch();
        for (final membershipDoc in page.docs) {
          final membershipData = membershipDoc.data();
          final currentResolved = membershipData['resolvedUserId'] as String?;
          final currentUserId = membershipData['userId'] as String?;
          if (currentResolved == userId && currentUserId == userId) {
            continue;
          }

          batch.set(
              membershipDoc.reference,
              {
                'resolvedUserId': userId,
                'userId': userId,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
          updatedCount++;
        }

        await batch.commit();
        cursor = page.docs.last;
        if (page.docs.length < pageSize) break;
      }
    }

    return updatedCount;
  }

  Future<void> createOrMergeUserByEmail({required AppUser newUser}) async {
    final normalizedEmail = _normalizeEmail(newUser.email);
    if (normalizedEmail.isEmpty) {
      throw Exception('User email cannot be empty.');
    }

    final candidateAliasIds = await _candidateAliasIdsForEmail(normalizedEmail);
    final optimisticMembershipRefs = await _prefetchMembershipRefsForAliases(
      aliasIds: candidateAliasIds,
    );
    final aliasIdsToBackfill = <String>{...candidateAliasIds};

    try {
      await _db.runTransaction((tx) async {
        final userRef = usersCollection.doc(newUser.id);
        final userSnap = await tx.get(userRef);
        final aliasRef = await resolveAliasForEmailForUpdate(
          tx: tx,
          email: normalizedEmail,
        );
        final aliasSnap = aliasRef != null ? await tx.get(aliasRef) : null;

        final userData = <String, dynamic>{
          ...newUser.toJson(),
          'id': newUser.id,
          'email': normalizedEmail,
          'emailNormalized': normalizedEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // All reads were executed above; writes begin here.
        if (!userSnap.exists) {
          tx.set(
              userRef,
              {
                ...userData,
                'createdAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        } else {
          tx.set(userRef, userData, SetOptions(merge: true));
        }

        if (aliasRef == null || aliasSnap == null || !aliasSnap.exists) {
          return;
        }

        aliasIdsToBackfill.add(aliasRef.id);

        final aliasData = aliasSnap.data() ?? <String, dynamic>{};
        final aliasUserId = aliasData['userId'] as String?;
        if (aliasUserId != null &&
            aliasUserId.isNotEmpty &&
            aliasUserId != newUser.id) {
          throw StateError(
            'Alias ${aliasRef.id} already points to $aliasUserId (new uid: ${newUser.id}).',
          );
        }

        tx.set(
            aliasRef,
            {
              'email': normalizedEmail,
              'userId': newUser.id,
              'migratedAt': FieldValue.serverTimestamp(),
              'migratedBy': newUser.id,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        // Opportunistic in-transaction updates for a small pre-fetched set.
        for (final membershipRef in optimisticMembershipRefs) {
          tx.set(
              membershipRef,
              {
                'resolvedUserId': newUser.id,
                'userId': newUser.id,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
      });

      final updatedMemberships = await _syncMembershipsForAliases(
        aliasIds: aliasIdsToBackfill,
        userId: newUser.id,
      );
      debugPrint(
        '✅ createOrMergeUserByEmail resolved ${aliasIdsToBackfill.length} alias id(s) and updated $updatedMemberships membership(s) for ${newUser.id}',
      );
    } catch (e) {
      debugPrint("🔥 Error in createOrMergeUserByEmail: $e");
      throw Exception("Failed to create or merge user by email: $e");
    }
  }

  Future<void> createAppUser({required AppUser newUser}) async {
    try {
      await usersCollection.doc(newUser.id).set(newUser.toJson());
    } catch (e) {
      debugPrint("🔥 Error creating app user ${newUser.id}: $e");
      throw Exception("Failed to create user: $e");
    }
  }

  Future<void> updateUser(AppUser updatedUser) async {
    try {
      await usersCollection.doc(updatedUser.id).set(updatedUser.toJson());
    } catch (e) {
      debugPrint("🔥 Error updating user ${updatedUser.id}: $e");
      throw Exception("Failed to update user: $e");
    }
  }

  // --- GET: Coach (legacy collection) ---
  Future<AppUser?> getCoach(String coachId) async {
    try {
      final doc = await _coachesCollection.doc(coachId).get();

      if (!doc.exists) {
        debugPrint("Legacy coach document not found for ID: $coachId");
        return null;
      }

      final raw = doc.data();
      if (raw is! Map<String, dynamic>) {
        debugPrint(
          "⚠️ Skipped coach ${doc.id} — invalid type ${raw.runtimeType}.",
        );
        return null;
      }
      return AppUser.fromJson(doc.id, raw);
    } catch (e) {
      debugPrint("🔥 Error getting coach $coachId: $e");
      return null;
    }
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    // Map to your AppUser/Coach/Swimmer model as you already do
    return AppUser.fromJson(snap.docs.first.id, data);
  }

  /// --- GET: My Profile Shortcut ---
  Future<AppUser?> getMyProfile() async {
    final myUid = _authService.currentUserId;
    if (myUid != null) {
      return await getUserDocument(myUid);
    }
    return null;
  }

  Future<bool> userExistsByEmail(String email) async {
    final snap =
        await usersCollection.where("email", isEqualTo: email).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<List<AppUser>> getUsersByEmails(List<String> emails) async {
    if (emails.isEmpty) return [];

    final normalized = emails.map((e) => e.toLowerCase()).toSet().toList();
    final users = <AppUser>[];

    try {
      for (var i = 0; i < normalized.length; i += 30) {
        final chunk = normalized.sublist(
          i,
          i + 30 > normalized.length ? normalized.length : i + 30,
        );

        final snapshot =
            await usersCollection.where('email', whereIn: chunk).get();

        for (final doc in snapshot.docs) {
          final user = _parseUserDoc(doc);
          if (user != null) {
            users.add(user);
          }
        }
      }
    } catch (e, s) {
      debugPrint('🔥 Error fetching users by emails: $e');
      debugPrintStack(stackTrace: s);
    }

    return users;
  }
}
