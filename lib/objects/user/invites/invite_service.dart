import 'dart:convert';

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

@immutable
class InviteMembershipContext {
  final String contextType;
  final String contextId;
  final String role;
  final String collection;

  const InviteMembershipContext({
    required this.contextType,
    required this.contextId,
    required this.role,
    this.collection = 'memberships',
  });

  Map<String, dynamic> toAliasContextJson() {
    return {'type': contextType, 'id': contextId, 'role': role};
  }
}

@immutable
class InviteResult {
  final String inviteId;
  final String membershipId;
  final String? aliasId;
  final String? resolvedUserId;
  final bool isAliasPrincipal;

  const InviteResult({
    required this.inviteId,
    required this.membershipId,
    required this.aliasId,
    required this.resolvedUserId,
    required this.isAliasPrincipal,
  });
}

@immutable
class MembershipCommandResult {
  final String status;
  final int entityVersion;
  final String eventId;
  final String? errorCode;
  final Map<String, dynamic> data;

  const MembershipCommandResult({
    required this.status,
    required this.entityVersion,
    required this.eventId,
    required this.errorCode,
    required this.data,
  });

  bool get isSuccess => status == 'applied' || status == 'no_op';
}

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
  }) : _inviteRepository = inviteRepository ?? InviteRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       userRepository =
           userRepository ??
           UserRepository(
             firestore ?? FirebaseFirestore.instance,
             authService: AuthService(firebaseAuth: auth),
           );

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  static const List<String> _membershipCollections = <String>[
    'memberships',
    'club_memberships',
    'team_memberships',
    'seat_memberships',
  ];

  String _stableDocId(String source) {
    return base64Url.encode(utf8.encode(source)).replaceAll('=', '');
  }

  String _aliasIdForEmail(String normalizedEmail) {
    return _stableDocId('alias:$normalizedEmail');
  }

  String _membershipDocId({
    required InviteMembershipContext context,
    String? aliasId,
    String? userId,
  }) {
    final principal = aliasId != null
        ? 'alias:$aliasId'
        : 'user:${userId ?? 'unknown'}';
    return _stableDocId(
      'membership:${context.collection}:${context.contextType}:${context.contextId}:${context.role}:$principal',
    );
  }

  String _inviteDocId({
    required InviteMembershipContext context,
    required String principalId,
    required bool isAliasPrincipal,
  }) {
    final principalPrefix = isAliasPrincipal ? 'alias' : 'user';
    return _stableDocId(
      'invite:${context.collection}:${context.contextType}:${context.contextId}:${context.role}:$principalPrefix:$principalId',
    );
  }

  String _inviteToken({
    required String inviteId,
    required String principalId,
    required bool isAliasPrincipal,
  }) {
    final principalPrefix = isAliasPrincipal ? 'alias' : 'user';
    return _stableDocId(
      'token:$inviteId:$principalPrefix:$principalId:${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String normalizedEmail,
  ) async {
    final byNormalized = await _firestore
        .collection('users')
        .where('emailNormalized', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byNormalized.docs.isNotEmpty) {
      return byNormalized.docs.first;
    }

    final byEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byEmail.docs.isNotEmpty) {
      return byEmail.docs.first;
    }

    return null;
  }

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

  Future<void> requestToJoinClub({required String clubId}) async {
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
      '🙋 Join request created for club=$clubId by user=${newUser.uid}',
    );
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
  // ✉️ CANONICAL INVITE FLOW (ALIAS-FIRST WITH IDEMPOTENT MEMBERSHIP UPSERT)
  // --------------------------------------------------------------------------

  InviteType _inviteTypeForContext(InviteMembershipContext context) {
    switch (context.contextType) {
      case 'club':
        return InviteType.clubInvite;
      case 'seat':
        return InviteType.seatInvite;
      default:
        return InviteType.coachToSwimmer;
    }
  }

  String _canonicalSourceApp(App app) {
    switch (app) {
      case App.swimSuite:
        return 'swim_suite';
      case App.swimAnalyzer:
        return 'swim_analyzer';
      case App.swimForge:
        return 'swim_forge';
    }
  }

  String _canonicalInviteTypeFor(InviteType type) {
    if (type == InviteType.seatInvite) {
      return 'seat';
    }
    return 'club_member';
  }

  String _canonicalRoleFromRaw(String rawRole) {
    final normalized = rawRole.trim().toLowerCase();
    if (normalized == 'clubadmin' || normalized == 'admin') return 'admin';
    if (normalized == 'swimmer') return 'swimmer';
    return 'coach';
  }

  String _defaultRoleForInviteType(InviteType type) {
    switch (type) {
      case InviteType.coachToSwimmer:
        return 'swimmer';
      case InviteType.swimmerToCoach:
        return 'coach';
      case InviteType.clubInvite:
        return 'coach';
      case InviteType.seatInvite:
        return 'coach';
    }
  }

  String _newRequestId(String prefix) {
    final userId = _auth.currentUser?.uid ?? 'anonymous';
    return '${prefix}_${userId}_${DateTime.now().microsecondsSinceEpoch}';
  }

  MembershipCommandResult _parseMembershipCommandResult(dynamic raw) {
    final payload = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return MembershipCommandResult(
      status: (payload['status'] ?? 'error').toString(),
      entityVersion: (payload['entityVersion'] as num?)?.toInt() ?? 0,
      eventId: (payload['eventId'] ?? '').toString(),
      errorCode: payload['errorCode'] as String?,
      data: payload,
    );
  }

  Future<MembershipCommandResult> _callMembershipCommand({
    required String callableName,
    required Map<String, dynamic> payload,
  }) async {
    final callable = _functions.httpsCallable(callableName);
    final result = await callable.call(payload);
    return _parseMembershipCommandResult(result.data);
  }

  Future<MembershipCommandResult> inviteMember({
    required String email,
    required InviteType type,
    required App app,
    required String clubId,
    String? relatedEntityId,
    String? role,
    String? name,
    String? clubName,
    App sourceApp = App.swimSuite,
    bool sendEmail = true,
    String? requestId,
  }) async {
    final inviter = _auth.currentUser;
    if (inviter == null) throw Exception('No logged-in user.');

    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw Exception('Email cannot be empty.');
    }
    final normalizedClubId = clubId.trim();
    if (normalizedClubId.isEmpty) {
      throw Exception('clubId is required for inviteMember.');
    }

    final normalizedRole = role == null || role.trim().isEmpty
        ? _defaultRoleForInviteType(type)
        : _canonicalRoleFromRaw(role);

    final commandResult = await _callMembershipCommand(
      callableName: 'membership_invite_member',
      payload: {
        'requestId': requestId ?? _newRequestId('invite_member'),
        'inviterId': inviter.uid,
        'inviterEmail': _normalizeEmail(inviter.email ?? ''),
        'inviterName': inviter.displayName ?? inviter.email ?? '',
        'inviteeEmail': normalizedEmail,
        'inviteType': _canonicalInviteTypeFor(type),
        'targetRole': normalizedRole,
        'sourceApp': _canonicalSourceApp(sourceApp),
        'app': app.name,
        'clubId': normalizedClubId,
        if (relatedEntityId != null && relatedEntityId.trim().isNotEmpty)
          'relatedEntityId': relatedEntityId.trim(),
      },
    );

    if (sendEmail && commandResult.isSuccess) {
      try {
        final inviteId = commandResult.data['inviteId']?.toString();
        final callable = _functions.httpsCallable('sendInviteEmail');
        await callable.call({
          'email': normalizedEmail,
          'senderId': inviter.uid,
          'senderEmail': _normalizeEmail(inviter.email ?? ''),
          'senderName':
              inviter.displayName ?? inviter.email ?? 'A Swim-Suite coach',
          'inviteId': inviteId,
          'type': type.name,
          'inviteType': _canonicalInviteTypeFor(type),
          'targetRole': normalizedRole,
          'sourceApp': _canonicalSourceApp(sourceApp),
          'clubId': normalizedClubId,
          if (relatedEntityId != null && relatedEntityId.trim().isNotEmpty)
            'relatedEntityId': relatedEntityId.trim(),
          'app': app.name,
          if (clubName != null && clubName.trim().isNotEmpty)
            'clubName': clubName.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        });
      } catch (e, st) {
        debugPrint(
          '⚠️ Invite email send failed after canonical upsert: $e\n$st',
        );
      }
    }

    return commandResult;
  }

  Future<MembershipCommandResult> assignSwimmerToGroup({
    required String clubId,
    required String swimmerId,
    required String groupId,
    String? requestId,
    App sourceApp = App.swimSuite,
  }) {
    return _callMembershipCommand(
      callableName: 'membership_assign_swimmer_to_group',
      payload: {
        'requestId': requestId ?? _newRequestId('assign_group'),
        'clubId': clubId.trim(),
        'swimmerId': swimmerId.trim(),
        'groupId': groupId.trim(),
        'sourceApp': _canonicalSourceApp(sourceApp),
      },
    );
  }

  Future<MembershipCommandResult> removeSwimmerFromGroup({
    required String clubId,
    required String swimmerId,
    String? requestId,
    App sourceApp = App.swimSuite,
  }) {
    return _callMembershipCommand(
      callableName: 'membership_remove_swimmer_from_group',
      payload: {
        'requestId': requestId ?? _newRequestId('remove_group'),
        'clubId': clubId.trim(),
        'swimmerId': swimmerId.trim(),
        'sourceApp': _canonicalSourceApp(sourceApp),
      },
    );
  }

  Future<MembershipCommandResult> grantSeat({
    required String clubId,
    required String userId,
    String? requestId,
    App sourceApp = App.swimSuite,
  }) {
    return _callMembershipCommand(
      callableName: 'membership_grant_seat',
      payload: {
        'requestId': requestId ?? _newRequestId('grant_seat'),
        'clubId': clubId.trim(),
        'userId': userId.trim(),
        'sourceApp': _canonicalSourceApp(sourceApp),
      },
    );
  }

  Future<MembershipCommandResult> revokeSeat({
    required String clubId,
    required String userId,
    String? requestId,
    App sourceApp = App.swimSuite,
  }) {
    return _callMembershipCommand(
      callableName: 'membership_revoke_seat',
      payload: {
        'requestId': requestId ?? _newRequestId('revoke_seat'),
        'clubId': clubId.trim(),
        'userId': userId.trim(),
        'sourceApp': _canonicalSourceApp(sourceApp),
      },
    );
  }

  Future<InviteResult> invite({
    required String email,
    required String name,
    required InviteMembershipContext context,
    App app = App.swimSuite,
    bool sendEmail = true,
  }) async {
    final inviter = _auth.currentUser;
    if (inviter == null) throw Exception('No logged-in user.');

    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw Exception('Email cannot be empty.');
    }

    final membershipCollection =
        _membershipCollections.contains(context.collection)
        ? context.collection
        : 'memberships';
    final normalizedContext = InviteMembershipContext(
      contextType: context.contextType,
      contextId: context.contextId,
      role: context.role,
      collection: membershipCollection,
    );

    final existingUserDoc = await _findUserByEmail(normalizedEmail);
    final existingUserId = existingUserDoc?.id;
    final isAliasPrincipal = existingUserId == null;
    final aliasId = isAliasPrincipal ? _aliasIdForEmail(normalizedEmail) : null;
    final principalId = aliasId ?? existingUserId!;
    final membershipId = _membershipDocId(
      context: normalizedContext,
      aliasId: aliasId,
      userId: existingUserId,
    );
    final inviteId = _inviteDocId(
      context: normalizedContext,
      principalId: principalId,
      isAliasPrincipal: isAliasPrincipal,
    );
    final inviteToken = _inviteToken(
      inviteId: inviteId,
      principalId: principalId,
      isAliasPrincipal: isAliasPrincipal,
    );

    final inviteType = _inviteTypeForContext(normalizedContext);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      String? resolvedUserId = existingUserId;
      final aliasRef = isAliasPrincipal
          ? _firestore.collection('aliases').doc(aliasId)
          : null;
      final membershipRef = _firestore
          .collection(membershipCollection)
          .doc(membershipId);
      final inviteRef = _firestore.collection('invites').doc(inviteId);

      // Firestore transactions require reads before writes.
      final aliasSnap = aliasRef != null
          ? await transaction.get(aliasRef)
          : null;
      final membershipSnap = await transaction.get(membershipRef);
      final inviteSnap = await transaction.get(inviteRef);

      if (isAliasPrincipal) {
        final aliasContext = normalizedContext.toAliasContextJson();

        if (aliasSnap != null && aliasSnap.exists) {
          final aliasData = aliasSnap.data() ?? <String, dynamic>{};
          final aliasUserId = aliasData['userId'] as String?;
          if (aliasUserId != null && aliasUserId.isNotEmpty) {
            resolvedUserId = aliasUserId;
          }

          transaction.set(aliasRef!, {
            'email': normalizedEmail,
            if (name.trim().isNotEmpty) 'name': name.trim(),
            'invitedBy': inviter.uid,
            'inviteContexts': FieldValue.arrayUnion([aliasContext]),
            'updatedAt': now,
          }, SetOptions(merge: true));
        } else {
          transaction.set(aliasRef!, {
            'email': normalizedEmail,
            if (name.trim().isNotEmpty) 'name': name.trim(),
            'invitedBy': inviter.uid,
            'inviteContexts': [aliasContext],
            'userId': null,
            'createdAt': now,
            'updatedAt': now,
          });
        }
      }

      final membershipData = <String, dynamic>{
        'contextType': normalizedContext.contextType,
        'contextId': normalizedContext.contextId,
        'role': normalizedContext.role,
        if (aliasId != null) 'aliasId': aliasId,
        if (existingUserId != null) 'userId': existingUserId,
        if (resolvedUserId != null) 'resolvedUserId': resolvedUserId,
        'updatedAt': now,
      };

      if (membershipSnap.exists) {
        transaction.set(membershipRef, membershipData, SetOptions(merge: true));
      } else {
        transaction.set(membershipRef, {...membershipData, 'createdAt': now});
      }

      final inviteData = <String, dynamic>{
        'inviterId': inviter.uid,
        'inviterEmail': _normalizeEmail(inviter.email ?? ''),
        'inviteeEmail': normalizedEmail,
        'type': inviteType.name,
        'app': app.name,
        'createdAt': now,
        'accepted': null,
        'acceptedUserId': null,
        'acceptedAt': null,
        if (normalizedContext.contextType == 'club')
          'clubId': normalizedContext.contextId,
        if (normalizedContext.contextType != 'club')
          'relatedEntityId': normalizedContext.contextId,
        'contextType': normalizedContext.contextType,
        'contextId': normalizedContext.contextId,
        'role': normalizedContext.role,
        'membershipCollection': membershipCollection,
        'membershipId': membershipId,
        if (aliasId != null) 'aliasId': aliasId,
        if (resolvedUserId != null) 'resolvedUserId': resolvedUserId,
        'inviteToken': inviteToken,
        'updatedAt': now,
      };

      if (inviteSnap.exists) {
        transaction.set(inviteRef, inviteData, SetOptions(merge: true));
      } else {
        transaction.set(inviteRef, inviteData);
      }
    });

    if (sendEmail) {
      try {
        final callable = _functions.httpsCallableFromUrl(
          "https://sendinviteemail-dvni7kn54wa-ew.a.run.app",
        );
        await callable.call({
          'email': normalizedEmail,
          'senderId': inviter.uid,
          'senderName':
              inviter.displayName ?? inviter.email ?? 'A Swimify coach',
          'app': app.name,
          'type': inviteType.name,
          'contextType': normalizedContext.contextType,
          'contextId': normalizedContext.contextId,
          'role': normalizedContext.role,
          'membershipCollection': membershipCollection,
          'membershipId': membershipId,
          'inviteId': inviteId,
          'inviteToken': inviteToken,
          'aliasId': aliasId,
        });
      } catch (e, st) {
        debugPrint('⚠️ Canonical invite email failed (invite stored): $e\n$st');
      }
    }

    return InviteResult(
      inviteId: inviteId,
      membershipId: membershipId,
      aliasId: aliasId,
      resolvedUserId: existingUserId,
      isAliasPrincipal: isAliasPrincipal,
    );
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
    final normalizedClubId = clubId?.trim();
    final canUseCanonicalCommand =
        normalizedClubId != null &&
        normalizedClubId.isNotEmpty &&
        (type == InviteType.clubInvite || type == InviteType.seatInvite);

    if (canUseCanonicalCommand) {
      final result = await inviteMember(
        email: normalizedEmail,
        type: type,
        app: app,
        clubId: normalizedClubId,
        relatedEntityId: groupId,
        role: _defaultRoleForInviteType(type),
        clubName: clubName,
        sourceApp: App.swimSuite,
        sendEmail: true,
        requestId: _newRequestId('send_invite'),
      );
      if (!result.isSuccess) {
        throw Exception(
          'Invite command failed: ${result.errorCode ?? result.status}',
        );
      }
      return;
    }

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
              .where(
                (invite) =>
                    _normalizeEmail(invite.inviteeEmail) == email ||
                    invite.inviterId == userId ||
                    invite.acceptedUserId == userId,
              )
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
        .map(
          (snap) =>
              snap.docs.map((d) => AppInvite.fromJson(d.id, d.data())).toList(),
        );
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
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await inviteMember(
        email: normalizedEmail,
        type: type,
        app: app,
        clubId: clubId,
        relatedEntityId: groupId,
        role: _defaultRoleForInviteType(type),
        sourceApp: App.swimSuite,
        sendEmail: true,
        requestId: _newRequestId('send_invite_pending_user'),
        name: currentUser?.displayName,
      );
    } catch (e, st) {
      debugPrint('❌ Error calling inviteMember command: $e\n$st');
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
    AppInvite? appInvite,
    String? inviteId,
    required String userId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No logged-in user.');
    final targetInviteId = inviteId ?? appInvite?.id;
    if (targetInviteId == null || targetInviteId.isEmpty) {
      throw Exception('Invite ID is required.');
    }

    try {
      String? acceptedAliasId;

      await _firestore.runTransaction((transaction) async {
        final inviteRef = _firestore.collection('invites').doc(targetInviteId);
        final inviteSnap = await transaction.get(inviteRef);
        if (!inviteSnap.exists) {
          throw StateError('Invite $targetInviteId does not exist.');
        }

        final data = inviteSnap.data() ?? <String, dynamic>{};
        final isAlreadyAccepted = data['accepted'] == true;
        final existingAcceptedUserId = data['acceptedUserId'] as String?;
        final aliasId = data['aliasId'] as String?;
        final inviteeEmail = data['inviteeEmail'] as String? ?? '';
        acceptedAliasId = aliasId;
        final aliasRef = (aliasId != null && aliasId.isNotEmpty)
            ? _firestore.collection('aliases').doc(aliasId)
            : null;
        final aliasSnap = aliasRef != null
            ? await transaction.get(aliasRef)
            : null;

        if (isAlreadyAccepted) {
          if (existingAcceptedUserId == userId) {
            return;
          }
          throw StateError(
            'Invite $targetInviteId was already accepted by $existingAcceptedUserId.',
          );
        }

        if (aliasRef != null) {
          if (aliasSnap == null || !aliasSnap.exists) {
            // Defensive recovery for bad state: recreate missing alias document.
            transaction.set(aliasRef, {
              'email': _normalizeEmail(inviteeEmail),
              'userId': userId,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'migratedAt': FieldValue.serverTimestamp(),
              'migratedBy': 'invite_accept',
            }, SetOptions(merge: true));
          } else {
            final aliasData = aliasSnap.data() ?? <String, dynamic>{};
            final aliasUserId = aliasData['userId'] as String?;
            if (aliasUserId != null &&
                aliasUserId.isNotEmpty &&
                aliasUserId != userId) {
              throw StateError(
                'Alias $aliasId belongs to $aliasUserId and cannot be accepted by $userId.',
              );
            }

            transaction.set(aliasRef, {
              'userId': userId,
              'migratedAt': FieldValue.serverTimestamp(),
              'migratedBy': 'invite_accept',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }

        transaction.set(inviteRef, {
          'accepted': true,
          'acceptedUserId': userId,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (acceptedAliasId != null && acceptedAliasId!.isNotEmpty) {
        await userRepository.syncMembershipsForAlias(
          aliasId: acceptedAliasId!,
          userId: userId,
        );
      }

      debugPrint(
        '✅ Invite $targetInviteId accepted successfully by ${user.uid}',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ FirebaseFunctionsException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Error in acceptInvite: $e\n$st');
      rethrow;
    }
  }

  Future<void> acceptInviteById({
    required String inviteId,
    required String userId,
  }) {
    return acceptInvite(inviteId: inviteId, userId: userId);
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
          )
          .get();

      final Set<String> swimmerIds = {};

      for (final doc in snapshot.docs) {
        final invite = AppInvite.fromJson(doc.id, doc.data());
        final swimmerId = _resolveSwimmerIdForCoach(
          invite: invite,
          coachId: coachId,
        );
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
    final users = await userRepository.getUsersByIds(swimmerIds.toList());

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
      final invites = await getInvitesByEmailAll(email);
      if (invites.isEmpty) return null;
      return invites.first;
    } catch (e, st) {
      debugPrint('❌ Failed to fetch invite by email: $e\n$st');
      rethrow;
    }
  }

  Future<List<AppInvite>> getInvitesByEmailAll(String email) async {
    try {
      final normalized = _normalizeEmail(email);
      final invites = await _inviteRepository.getInvitesByEmail(normalized);
      if (invites.isEmpty) return const <AppInvite>[];

      final ranked = invites.toList()
        ..sort((a, b) {
          final rankComparison = _inviteRank(a).compareTo(_inviteRank(b));
          if (rankComparison != 0) {
            return rankComparison;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      return ranked;
    } catch (e, st) {
      debugPrint('❌ Failed to fetch invites by email: $e\n$st');
      rethrow;
    }
  }

  int _inviteRank(AppInvite invite) {
    final status = _normalizeStatus(invite);
    final declinedOrRevoked = status == 'declined' || status == 'revoked';
    if (!declinedOrRevoked) {
      if (invite.accepted == null) return 0;
      if (invite.accepted == false) return 1;
    }
    if (invite.accepted == true) return 2;
    return 3;
  }

  String _normalizeStatus(AppInvite invite) {
    return invite.status?.trim().toLowerCase() ?? '';
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

      final caseA =
          invite.inviterId == userId &&
          _normalizeEmail(invite.inviteeEmail) == normalized;

      final caseB =
          _normalizeEmail(invite.inviterEmail) == normalized &&
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
    return _inviteRepository.collection
        .where('app', isEqualTo: app.name)
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
