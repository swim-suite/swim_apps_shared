import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../objects/user/invites/app_enums.dart';
import '../objects/user/invites/app_invite.dart';
import '../objects/user/invites/invite_type.dart';

class InviteRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'invites';

  InviteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get collection =>
      _firestore.collection(_collectionPath);

  // --------------------------------------------------------------------------
  // ✉️ BASIC CRUD
  // --------------------------------------------------------------------------

  /// 📩 Send (create) an invite.
  Future<void> sendInvite(AppInvite invite) async {
    try {
      await collection.doc(invite.id).set(invite.toJson());
      debugPrint('✅ Invite sent: ${invite.id}');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore error sending invite: ${e.message}');
      rethrow;
    }
  }

  /// ✅ Accept an invite.
  Future<void> acceptInvite(String inviteId, String acceptedUserId) async {
    try {
      await collection.doc(inviteId).update({
        'accepted': true,
        'acceptedUserId': acceptedUserId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Invite accepted: $inviteId');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore error accepting invite: ${e.message}');
      rethrow;
    }
  }

  /// 🚫 Revoke or delete an invite.
  Future<void> revokeInvite(String inviteId) async {
    try {
      await collection.doc(inviteId).update({'accepted': false});
      debugPrint('🚫 Invite revoked: $inviteId');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore error revoking invite: ${e.message}');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // 🔍 QUERIES
  // --------------------------------------------------------------------------

  /// 🔍 Get all invites sent by a user (optionally filtered by accepted).
  Future<List<AppInvite>> getInvitesByInviter(String inviterId,
      {bool? accepted}) async {
    try {
      Query<Map<String, dynamic>> query =
          collection.where('inviterId', isEqualTo: inviterId);
      if (accepted != null)
        query = query.where('accepted', isEqualTo: accepted);

      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => AppInvite.fromJson(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get invites by inviter: $e');
      rethrow;
    }
  }

  /// 🔍 Get all invites received by a specific email (optionally filtered by accepted).
  Future<List<AppInvite>> getInvitesByInviteeEmail(String email,
      {bool? isAccepted}) async {
    try {
      final normalized = email.trim().toLowerCase();
      Query<Map<String, dynamic>> query =
          collection.where('receiverEmail', isEqualTo: normalized);
      if (isAccepted != null) {
        query = query.where('accepted', isEqualTo: isAccepted);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((d) => AppInvite.fromJson(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get invites by email: $e');
      rethrow;
    }
  }

  /// 🔍 Stream all active (accepted) invite links for a user.
  /// Works in BOTH directions:
  /// - user invited someone else
  /// - someone else invited the user
  ///
  /// This allows visibility of analyses, training plans, etc.
  Stream<List<AppInvite>> streamActiveViewerLinks({
    required String? userId,
    required String email,
    required App app,
  }) {
    final normalizedEmail = email.trim().toLowerCase();

    // Stream where user is the RECEIVER (someone invited them)
    final incoming = collection
        .where('receiverEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'accepted')
        .where('app', isEqualTo: app.name)
        .snapshots();

    // Stream where user is the SENDER (they invited someone else)
    final outgoing = collection
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'accepted')
        .where('app', isEqualTo: app.name)
        .snapshots();

    // Combine both streams into a single stream
    return Rx.combineLatest2(
      incoming,
      outgoing,
      (QuerySnapshot<Map<String, dynamic>> inc,
          QuerySnapshot<Map<String, dynamic>> out) {
        final allDocs = [...inc.docs, ...out.docs];

        // Convert to model
        return allDocs
            .map((doc) => AppInvite.fromJson(doc.id, doc.data()))
            .toList();
      },
    );
  }

  /// 🔍 Fetch all invites where the receiverEmail matches this email.
  /// Works for invites/{inviteId}
  Future<List<AppInvite>> getInviteByReceiverEmail(
      {required String email}) async {
    try {
      final normalized = email.trim().toLowerCase();

      final snapshot =
          await collection.where('receiverEmail', isEqualTo: normalized).get();

      return snapshot.docs
          .map((doc) => AppInvite.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      debugPrint('❌ Failed to get invites by email: $e');
      debugPrint('Stack trace:\n$st');
      rethrow;
    }
  }

  /// 🔍 Alias for convenience used by InviteService.getInviteByEmail()
  Future<List<AppInvite>> getInvitesByEmail(String email) async {
    return getInvitesByInviteeEmail(email);
  }

  /// 🔍 Get all accepted swimmers for a given coach.
  Future<List<AppInvite>> getAcceptedSwimmersForCoach(String coachId) async {
    try {
      // 1️⃣ Get ALL accepted coach↔swimmer invites
      final snapshot = await collection
          .where('accepted', isEqualTo: true)
          .where(
        'type',
        whereIn: [
          InviteType.coachToSwimmer.name,
          InviteType.swimmerToCoach.name,
        ],
      )
          .get();

      // 2️⃣ Filter in memory for this coach
      return snapshot.docs
          .map((d) => AppInvite.fromJson(d.id, d.data()))
          .where((AppInvite invite) =>
      // Coach invited swimmer
      invite.inviterId == coachId ||
          // Swimmer invited coach (and coach accepted)
          invite.acceptedUserId == coachId)
          .toList();
    } catch (e, st) {
      debugPrint('❌ Failed to get accepted swimmers for coach: $e\n$st');
      rethrow;
    }
  }

  /// 🔍 Get all accepted coaches for a given swimmer.
  Future<List<AppInvite>> getAcceptedCoachesForSwimmer(String swimmerId) async {
    try {
      final snapshot = await collection
          .where('acceptedUserId', isEqualTo: swimmerId)
          .where('type', isEqualTo: InviteType.coachToSwimmer.name)
          .where('accepted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((d) => AppInvite.fromJson(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get accepted coaches: $e');
      rethrow;
    }
  }

  /// 🔎 Check if a link (invite) exists between two users.
  Future<bool> isLinked({
    required String inviterId,
    required String acceptedUserId,
  }) async {
    try {
      final snapshot = await collection
          .where('inviterId', isEqualTo: inviterId)
          .where('acceptedUserId', isEqualTo: acceptedUserId)
          .where('accepted', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check link: $e');
      rethrow;
    }
  }

  /// 🔁 Stream accepted invites (for live UI updates).
  Stream<List<AppInvite>> streamAcceptedInvitesForCoach(String coachId) {
    return collection
        .where('inviterId', isEqualTo: coachId)
        .where('accepted', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AppInvite.fromJson(d.id, d.data())).toList());
  }

  // --------------------------------------------------------------------------
  // 🏢 CLUB CONTEXTUAL
  // --------------------------------------------------------------------------

  /// 📋 Get all *pending* invites associated with a specific club.
  Future<List<AppInvite>> getPendingInvitesByClub(String clubId) async {
    try {
      final snapshot = await collection
          .where('clubId', isEqualTo: clubId)
          .where('accepted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AppInvite.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ InviteRepository.getPendingInvitesByClub failed: $e');
      rethrow;
    }
  }
}
