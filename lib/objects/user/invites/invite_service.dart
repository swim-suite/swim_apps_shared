import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/auth_service.dart';
import 'package:swim_apps_shared/objects/user/invites/app_enums.dart';
import 'package:swim_apps_shared/objects/user/invites/app_invite.dart';
import 'package:swim_apps_shared/objects/user/invites/invite_type.dart';
import 'package:swim_apps_shared/repositories/invite_repository.dart';
import 'package:swim_apps_shared/repositories/user_repository.dart';

import '../user.dart';
import '../user_types.dart';

class InviteService {
  final InviteRepository _inviteRepository;
  final UserRepository userRepository;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  InviteService({
    InviteRepository? inviteRepository,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    UserRepository? userRepository,
  })  : _inviteRepository = inviteRepository ?? InviteRepository(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
        userRepository = userRepository ??
            UserRepository(
              firestore ?? FirebaseFirestore.instance,
              authService: AuthService(firebaseAuth: auth),
            );

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// For an accepted coach<->swimmer invite, resolve the "other" user id,
  /// given the current coachId.
  ///
  /// Returns:
  /// - swimmerId if the invite represents a valid coach<->swimmer link
  /// - null if the invite doesn't involve the coach, or is missing fields
  String? _resolveSwimmerIdForCoach({
    required AppInvite invite,
    required String coachId,
  }) {
    // Coach invited swimmer => swimmer accepted => acceptedUserId is swimmerId
    if (invite.inviterId == coachId) {
      final swimmerId = invite.acceptedUserId;
      if (swimmerId == null || swimmerId.isEmpty) return null;
      if (swimmerId == coachId) return null; // safety: no self-link
      return swimmerId;
    }

    // Swimmer invited coach => coach accepted => inviterId is swimmerId
    if (invite.acceptedUserId == coachId) {
      final swimmerId = invite.inviterId;
      if (swimmerId.isEmpty) return null;
      if (swimmerId == coachId) return null; // safety: no self-link
      return swimmerId;
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // 🙋 REQUEST TO JOIN CLUB (user → club admin)
  // --------------------------------------------------------------------------

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
        '🙋 Join request created for club=$clubId by user=${newUser.uid}');
  }

  // --------------------------------------------------------------------------
  // 🔍 Fetch invite by Firestore document ID
  // --------------------------------------------------------------------------

  Future<AppInvite?> getInviteById(String inviteId) async {
    try {
      final doc = await _firestore.collection('invites').doc(inviteId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

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
    if (inviter == null) throw Exception('No logged-in user.');

    final normalizedEmail = _normalizeEmail(email);

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
      // pending (tri-state)
      acceptedUserId: null,
      acceptedAt: null,
    );

    await _inviteRepository.sendInvite(invite);
    debugPrint('📄 Invite document created in Firestore for $normalizedEmail');

    // Best-effort email
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
    }
  }

  // --------------------------------------------------------------------------
  // STREAMS
  // --------------------------------------------------------------------------

  Stream<AppInvite?> streamInviteForEmail({
    required String email,
    required App app,
  }) {
    final normalized = _normalizeEmail(email);

    return _firestore
        .collection('invites')
        .where('inviteeEmail', isEqualTo: normalized)
        .where('accepted', isNull: true)
        .where('app', isEqualTo: app.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return AppInvite.fromJson(doc.id, doc.data());
    });
  }

  Stream<AppInvite?> streamPendingReceivedInvites({
    required AppUser user,
    required App app,
    InviteType? inviteType,
  }) {
    final email = _normalizeEmail(user.email);

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
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return AppInvite.fromJson(doc.id, doc.data());
    });
  }

  Stream<List<AppInvite>> streamActiveLinksForUser({
    required AppUser user,
    required App app,
  }) {
    final email = _normalizeEmail(user.email);
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
              _normalizeEmail(invite.inviteeEmail) == email ||
              invite.inviterId == userId ||
              invite.acceptedUserId == userId)
          .toList();
    });
  }

  Stream<List<AppInvite>> streamPendingSentInvites({
    required String userId,
    required InviteType inviteType,
  }) {
    return _firestore
        .collection('invites')
        .where('inviterId', isEqualTo: userId)
        .where('type', isEqualTo: inviteType.name)
        .where('accepted', isNull: true)
        .where('app', isEqualTo: App.swimAnalyzer.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppInvite.fromJson(d.id, d.data())).toList());
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
    final normalizedEmail = _normalizeEmail(email);

    // Best-effort email via callable function name
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
      debugPrint('❌ Error calling sendInviteEmail: $e\n$st');
    }

    // Pre-create pending user
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

  Future<void> acceptInvite({
    required AppInvite appInvite,
    required String userId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');

    try {
      final updated = appInvite.copyWith(
        accepted: true,
        acceptedAt: DateTime.now(),
        acceptedUserId: userId,
      );

      await _firestore
          .collection('invites')
          .doc(updated.id)
          .update(updated.toJson());

      debugPrint('✅ Invite ${updated.id} accepted successfully by ${user.uid}');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ FirebaseFunctionsException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Error in acceptInvite: $e\n$st');
      rethrow;
    }
  }

  Future<void> revokeInvite({required String inviteId}) async {
    try {
      await _inviteRepository.collection.doc(inviteId).update({
        'accepted': false,
        'acceptedAt': FieldValue.serverTimestamp(),
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

  @Deprecated('Use getMyAcceptedSwimmerIds() instead.')
  Future<List<AppInvite>> getMyAcceptedSwimmers() async {
    final coach = _auth.currentUser;
    if (coach == null) throw Exception('No logged-in coach.');
    return _inviteRepository.getAcceptedSwimmersForCoach(coach.uid);
  }

  /// ✅ Preferred: returns unique swimmerIds linked to the *current* coach.
  Future<Set<String>> getMyAcceptedSwimmerIds() async {
    final coach = _auth.currentUser;
    if (coach == null) throw Exception('No logged-in coach.');
    return getAcceptedSwimmerIdsForCoach(coach.uid);
  }

  /// ✅ Core: returns unique swimmerIds linked to a coach (accepted, both directions)
  Future<Set<String>> getAcceptedSwimmerIdsForCoach(String coachId) async {
    try {
      final snapshot = await _inviteRepository.collection
          .where('accepted', isEqualTo: true)
          .where(
        'type',
        whereIn: [
          InviteType.coachToSwimmer.name,
          InviteType.swimmerToCoach.name,
        ],
      ).get();

      final Set<String> swimmerIds = {};

      for (final doc in snapshot.docs) {
        final invite = AppInvite.fromJson(doc.id, doc.data());
        final swimmerId =
            _resolveSwimmerIdForCoach(invite: invite, coachId: coachId);
        if (swimmerId != null) swimmerIds.add(swimmerId);
      }

      return swimmerIds;
    } catch (e, st) {
      debugPrint('❌ Failed to get accepted swimmerIds for coach: $e\n$st');
      rethrow;
    }
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

  /// ✅ Preferred API for UI & controllers
  /// Returns unique AppUser swimmers linked to the current coach
  Future<List<AppUser>> getMyAcceptedSwimmerUsers() async {
    final coach = _auth.currentUser;
    if (coach == null) {
      throw Exception('No logged-in coach.');
    }

    // 1️⃣ Get unique swimmer IDs (direction-safe, deduped)
    final swimmerIds = await getAcceptedSwimmerIdsForCoach(coach.uid);
    if (swimmerIds.isEmpty) return [];

    // 2️⃣ Hydrate into AppUser objects
    final users = await userRepository.getUsersByIds(
      swimmerIds.toList(),
    );

    // 3️⃣ Extra safety: only swimmers, never coach
    return users
        .where((u) => u.id != coach.uid && u.userType == UserType.swimmer)
        .toList();
  }

  // --------------------------------------------------------------------------
  // 🏢 CLUB / EMAIL CONTEXTUAL QUERIES
  // --------------------------------------------------------------------------

  Future<List<AppInvite>> getPendingInvitesByClub(String clubId) async {
    try {
      return await _inviteRepository.getPendingInvitesByClub(clubId);
    } catch (e) {
      debugPrint('❌ Failed to fetch pending invites by club: $e');
      rethrow;
    }
  }

  Future<AppInvite?> getInviteByEmail(String email) async {
    try {
      final normalized = _normalizeEmail(email);
      final invites = await _inviteRepository.getInvitesByEmail(normalized);

      if (invites.isEmpty) return null;

      invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final pending = invites.where((i) => i.accepted == null);
      if (pending.isNotEmpty) return pending.first;

      final accepted = invites.where((i) => i.accepted == true);
      if (accepted.isNotEmpty) return accepted.first;

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
    final normalized = _normalizeEmail(otherEmail);

    final snap = await _firestore
        .collection('invites')
        .where('accepted', isEqualTo: true)
        .where('app', isEqualTo: app.name)
        .get();

    for (final doc in snap.docs) {
      final invite = AppInvite.fromJson(doc.id, doc.data());

      final caseA = invite.inviterId == userId &&
          _normalizeEmail(invite.inviteeEmail) == normalized;

      final caseB = _normalizeEmail(invite.inviterEmail) == normalized &&
          invite.acceptedUserId == userId;

      if (caseA || caseB) return true;
    }

    return false;
  }

  Future<bool> hasPendingInviteTo({
    required String senderId,
    required String inviteeEmail,
    required InviteType type,
  }) async {
    final normalized = _normalizeEmail(inviteeEmail);

    final snap = await _inviteRepository.collection
        .where('inviterId', isEqualTo: senderId)
        .where('type', isEqualTo: type.name)
        .where('inviteeEmail', isEqualTo: normalized)
        .where('accepted', isNull: true)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Stream<AppInvite?> streamInviteForCoachAndSwimmer({
    required String coachId,
    required String swimmerId,
    required App app,
  }) {
    return _inviteRepository.collection.where('app', isEqualTo: app.name)
        .snapshots()
        .map((snap) {
      for (final doc in snap.docs) {
        final invite = AppInvite.fromJson(doc.id, doc.data());

        final resolvedSwimmerId = _resolveSwimmerIdForCoach(
          invite: invite,
          coachId: coachId,
        );

        if (resolvedSwimmerId == swimmerId) {
          return invite;
        }
      }
      return null;
    });
  }
}
