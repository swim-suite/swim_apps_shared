import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/objects/user/invites/app_enums.dart';
import 'package:swim_apps_shared/objects/user/invites/app_invite.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_type.dart';
import 'package:swim_apps_shared/repositories/invite_repository.dart';

import '../user.dart';

class InviteService {
  final InviteRepository _inviteRepository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  InviteService({
    InviteRepository? inviteRepository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _inviteRepository = inviteRepository ?? InviteRepository(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// --------------------------------------------------------------------------
  /// 🙋 REQUEST TO JOIN CLUB (user → club admin)
  /// --------------------------------------------------------------------------
  Future<void> requestToJoinClub({
    required String clubId,
  }) async {
    final newUser = _auth.currentUser;
    if (newUser == null) {
      throw Exception('No logged-in newUser.');
    }

    final email = newUser.email;
    if (email == null || email.isEmpty) {
      throw Exception('User has no email.');
    }

    final invite = AppInvite(
      id: 'join_${DateTime.now().millisecondsSinceEpoch}',
      inviterId: newUser.uid,
      inviterEmail: email,
      inviteeEmail: '',
      // not email-based
      type: InviteType.clubInvite,
      app: App.swimSuite,
      clubId: clubId,
      relatedEntityId: null,
      createdAt: DateTime.now(),
      accepted: false,
      acceptedUserId: null,
    );

    await _inviteRepository.sendInvite(invite);

    debugPrint(
      '🙋 Join request created for club=$clubId by newUser=${newUser.uid}',
    );
  }

  /// 🔍 Fetch a single invite by its Firestore document ID.
  /// Returns an [AppInvite] if found, or `null` if not found.
  Future<AppInvite?> getInviteById(String inviteId) async {
    try {
      final doc = await _firestore.collection('invites').doc(inviteId).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      // ✅ Matches: factory AppInvite.fromJson(String id, Map<String, dynamic> json)
      return AppInvite.fromJson(doc.id, data);
    } catch (e, st) {
      debugPrint('❌ Error fetching invite by ID: $e\n$st');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // ✉️ SEND INVITE (Firestore first, email optional)
  // --------------------------------------------------------------------------
  Future<void> sendInvite({
    required String email,
    required InviteType type,
    required App app,
    String? clubId,
    String? groupId,
    String? clubName,
  }) async {
    final inviter = _auth.currentUser;
    if (inviter == null) {
      throw Exception('No logged-in user.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    // 🔹 Map Dart enum to backend key
    String inviteTypeKey;
    switch (type) {
      case InviteType.coachToSwimmer:
        inviteTypeKey = 'coach_invite';
        break;
      case InviteType.clubInvite:
        inviteTypeKey = 'club_invite';
        break;
      default:
        inviteTypeKey = 'generic_invite';
    }

    // 1️⃣ Create the invite record in Firestore
    final invite = AppInvite(
      id: 'invite_${DateTime.now().millisecondsSinceEpoch}',
      inviterId: inviter.uid,
      inviterEmail: inviter.email ?? '',
      inviteeEmail: normalizedEmail,
      type: type,
      app: app,
      clubId: clubId,
      relatedEntityId: groupId,
      createdAt: DateTime.now(),
      accepted: null,
      // ✅ pending (tri-state)
      acceptedUserId: null,
      acceptedAt: null,
    );

    await _inviteRepository.sendInvite(invite);
    debugPrint('📄 Invite document created in Firestore for $normalizedEmail');

    // 2️⃣ Call Python Cloud Function via URL
    try {
      final callable = _functions.httpsCallableFromUrl(
        "https://sendinviteemail-dvni7kn54wa-ew.a.run.app",
      );

      await callable.call({
        'email': normalizedEmail,
        'senderId': inviter.uid,
        'senderName': inviter.displayName ?? inviter.email ?? 'A Swimify coach',
        'clubId': clubId,
        'groupId': groupId,
        'type': inviteTypeKey,
        'clubName': clubName,
        'app': app.name,
      });

      debugPrint('📧 Invite email sent via Python Cloud Function');
    } catch (e) {
      debugPrint('⚠️ Email sending failed (invite stored anyway): $e');
      // Do NOT throw — Firestore invite is valid even if email sending fails
    }
  }

  /// Streams the most recent *pending* invite for the user’s email.
  /// Returns null if none exist.
  Stream<AppInvite?> streamInviteForEmail({
    required String email,
    required App app,
  }) {
    final normalized = email.trim().toLowerCase();

    return _firestore
        .collection('invites')
        .where('inviteeEmail', isEqualTo: normalized)
        .where('accepted', isNull: true) // ✅ pending
        .where('app', isEqualTo: app.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      return AppInvite.fromJson(doc.id, data);
    });
  }

  Stream<AppInvite?> streamPendingReceivedInvites({
    required AppUser user,
    required App app,
    InviteType? inviteType,
  }) {
    final email = user.email.trim().toLowerCase();

    Query<Map<String, dynamic>> query = _firestore
        .collection('invites')
        .where('inviteeEmail', isEqualTo: email)
        .where('accepted', isNull: true)
        .where('app', isEqualTo: app.name);

    if (inviteType != null) {
      query = query.where('type', isEqualTo: inviteType.name);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return AppInvite.fromJson(doc.id, doc.data());
    });
  }

  Stream<List<AppInvite>> streamActiveLinksForUser({
    required AppUser user,
    required App app,
  }) {
    final email = user.email.trim().toLowerCase();
    final userId = user.id;

    return _firestore
        .collection('invites')
        .where('accepted', isEqualTo: true)
        .where('app', isEqualTo: app.name)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => AppInvite.fromJson(d.id, d.data()))
          .where((invite) =>
              invite.inviteeEmail == email || invite.inviterId == userId)
          .toList();
    });
  }

  /// Returns all pending invites sent by a user.
  Stream<List<AppInvite>> streamPendingSentInvites({
    required String userId,
    required InviteType inviteType,
  }) {
    return _firestore
        .collection('invites')
        .where('inviterId', isEqualTo: userId)
        .where('type', isEqualTo: inviteType.name)
        .where('accepted', isNull: true) // ✅ pending
        .where('app', isEqualTo: App.swimAnalyzer.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => AppInvite.fromJson(d.id, d.data())).toList();
    });
  }

  // --------------------------------------------------------------------------
  // 🧩 SEND INVITE + CREATE PENDING USER
  // --------------------------------------------------------------------------

  Future<void> sendInviteAndCreatePendingUser({
    required String email,
    required InviteType type,
    required App app,
    required String inviterId,
    required String clubId,
    String? groupId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // ----------------------------------------------------------------------
    // 📨 1. SEND EMAIL INVITE VIA CLOUD FUNCTION (best-effort)
    // ----------------------------------------------------------------------
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final sendInvite = functions.httpsCallable('sendInviteEmail');

      final currentUser = FirebaseAuth.instance.currentUser;
      final inviterEmail = currentUser?.email ?? '';
      final inviterName = currentUser?.displayName ?? '';

      final result = await sendInvite.call({
        'email': normalizedEmail,
        'senderId': inviterId,
        'senderEmail': inviterEmail,
        'senderName': inviterName,
        'type': type.name,
        'app': app.name,
        'clubId': clubId,
        'groupId': groupId,
      });
      debugPrint('📨 sendInviteEmail response: ${result.data}');
    } catch (e, st) {
      debugPrint('❌ Error calling sendInviteEmail: $e');
      debugPrint('Stack: $st');
      // Do NOT rethrow — continue with user creation
    }

    // ----------------------------------------------------------------------
    // 👤 2. PRE-CREATE LOCAL PENDING USER IN FIRESTORE
    // ----------------------------------------------------------------------
    final safeDocId = normalizedEmail.replaceAll('.', ',');
    final ref = _firestore.collection('users').doc(safeDocId);

    final role = type == InviteType.clubInvite ? 'coach' : 'swimmer';

    await ref.set({
      'email': normalizedEmail,
      'role': role,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'invitedBy': inviterId,
      'clubId': clubId,
      'app': app.name,
    }, SetOptions(merge: true));

    debugPrint('✅ Pending user created locally for $normalizedEmail');
  }

  // --------------------------------------------------------------------------
  // ✅ ACCEPT / DECLINE INVITES
  // --------------------------------------------------------------------------

  /// Accepts an invite.
  Future<void> acceptInvite({
    required AppInvite appInvite,
    required String userId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    try {
      final updatedAppInvite = appInvite.copyWith(
        accepted: true,
        acceptedAt: DateTime.now(),
        acceptedUserId: userId,
      );

      await _firestore
          .collection('invites')
          .doc(updatedAppInvite.id)
          .update(updatedAppInvite.toJson());

      debugPrint(
          '✅ Invite ${updatedAppInvite.id} accepted successfully by ${user.uid}');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ FirebaseFunctionsException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Error in acceptInvite: $e\n$st');
      rethrow;
    }
  }

  /// Declines (denies) an invite.
  /// tri-state:
  /// - pending: accepted == null
  /// - denied: accepted == false
  /// - accepted: accepted == true
  Future<void> revokeInvite({required String inviteId}) async {
    try {
      await _inviteRepository.collection.doc(inviteId).update({
        'accepted': false, // ✅ denied
        'acceptedAt': FieldValue.serverTimestamp(), // ✅ keep decision timestamp
        'acceptedUserId': null,
        'revokedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("🚫 Invite denied for invite $inviteId");
    } catch (e, st) {
      debugPrint("❌ Error revoking invite: $e\n$st");
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 🔍 LOOKUPS
  // --------------------------------------------------------------------------

  Future<List<AppInvite>> getMyAcceptedSwimmers() async {
    final coach = _auth.currentUser;
    if (coach == null) throw Exception('No logged-in coach.');
    return _inviteRepository.getAcceptedSwimmersForCoach(coach.uid);
  }

  Future<List<AppInvite>> getMyAcceptedCoaches() async {
    final swimmer = _auth.currentUser;
    if (swimmer == null) throw Exception('No logged-in swimmer.');
    return _inviteRepository.getAcceptedCoachesForSwimmer(swimmer.uid);
  }

  Future<bool> hasLinkWith(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');
    return _inviteRepository.isLinked(
      inviterId: user.uid,
      acceptedUserId: otherUserId,
    );
  }

  // --------------------------------------------------------------------------
  // 🏢 CLUB / EMAIL CONTEXTUAL QUERIES
  // --------------------------------------------------------------------------

  Future<List<AppInvite>> getPendingInvitesByClub(String clubId) async {
    try {
      // NOTE: ensure repository uses accepted == null for "pending"
      return await _inviteRepository.getPendingInvitesByClub(clubId);
    } catch (e) {
      debugPrint('❌ Failed to fetch pending invites by club: $e');
      rethrow;
    }
  }

  Future<AppInvite?> getInviteByEmail(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      final invites = await _inviteRepository.getInvitesByEmail(normalized);

      if (invites.isEmpty) return null;

      // Always sort newest first
      invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 1️⃣ Prefer pending invites
      final pending = invites.where((i) => i.accepted == null);
      if (pending.isNotEmpty) return pending.first;

      // 2️⃣ Otherwise return most recent accepted invite
      final accepted = invites.where((i) => i.accepted == true);
      if (accepted.isNotEmpty) return accepted.first;

      // 3️⃣ Otherwise return most recent denied invite
      final denied = invites.where((i) => i.accepted == false);
      if (denied.isNotEmpty) return denied.first;

      return null;
    } catch (e, st) {
      debugPrint('❌ Failed to fetch invite by email: $e\n$st');
      rethrow;
    }
  }

  Future<String?> getAppForInviteEmail({required String email}) async {
    final invite = await getInviteByEmail(email);
    return invite?.app.name;
  }

  Future<bool> hasActiveLinkBetween({
    required String userId,
    required String otherEmail,
    required App app,
  }) async {
    final normalized = otherEmail.trim().toLowerCase();

    // 1️⃣ Get all accepted invites in this app
    final snap = await _firestore
        .collection('invites')
        .where('accepted', isEqualTo: true)
        .where('app', isEqualTo: app.name)
        .get();

    // 2️⃣ Check BOTH sides of the relationship
    for (final doc in snap.docs) {
      final invite = AppInvite.fromJson(doc.id, doc.data());

      // CASE A: user invited the other person
      final caseA = invite.inviterId == userId &&
          invite.inviteeEmail.toLowerCase() == normalized;

      // CASE B: other person invited the user
      final caseB = invite.inviterEmail.toLowerCase() == normalized &&
          invite.acceptedUserId == userId;

      if (caseA || caseB) {
        return true;
      }
    }

    return false;
  }

  Future<bool> hasPendingInviteTo({
    required String senderId,
    required String inviteeEmail,
    required InviteType type,
  }) async {
    final normalized = inviteeEmail.trim().toLowerCase();

    // ✅ Field names aligned with AppInvite schema:
    // inviterId, inviteeEmail, type, accepted
    final snap = await _inviteRepository.collection
        .where('inviterId', isEqualTo: senderId)
        .where('type', isEqualTo: type.name)
        .where('inviteeEmail', isEqualTo: normalized)
        .where('accepted', isNull: true) // ✅ pending
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }
}
