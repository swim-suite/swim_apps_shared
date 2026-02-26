import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/repositories/user_repository.dart';

import '../user.dart';
import 'app_enums.dart';
import 'invite_type.dart';

@immutable
class AppInvite {
  final String id;
  final String inviterId;
  final String inviterEmail;
  final String inviteeEmail;
  final InviteType type;
  final App app;
  final DateTime createdAt;
  final bool? accepted;
  final String? acceptedUserId;
  final String? clubId;
  final String? relatedEntityId;
  final DateTime? acceptedAt;
  final String? status;

  const AppInvite({
    required this.id,
    required this.inviterId,
    required this.inviterEmail,
    required this.inviteeEmail,
    required this.type,
    required this.app,
    required this.createdAt,
    this.accepted,
    this.acceptedUserId,
    this.clubId,
    this.relatedEntityId,
    this.acceptedAt,
    this.status,
  });

  factory AppInvite.fromJson(String id, Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.parse(v);
      throw ArgumentError('Unsupported date value type: ${v.runtimeType}');
    }

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return AppInvite(
      id: id,
      inviterId: (json['inviterId'] ?? json['senderId'] ?? '')
          .toString()
          .trim(),
      inviterEmail: (json['inviterEmail'] ?? json['senderEmail'] ?? '')
          .toString(),
      inviteeEmail: (json['inviteeEmail'] ?? json['receiverEmail'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      type: InviteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InviteType.coachToSwimmer,
      ),
      app: App.values.firstWhere(
        (e) => e.name == json['app'],
        orElse: () => App.swimAnalyzer,
      ),
      createdAt: parseDate(json['createdAt']),
      accepted: json['accepted'] as bool? ?? false,
      acceptedUserId: json['acceptedUserId'] as String?,
      clubId: json['clubId'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      acceptedAt: parseDateNullable(json['acceptedAt']),
      status: (json['status'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inviterId': inviterId,
      'inviterEmail': inviterEmail,
      'inviteeEmail': inviteeEmail,
      'type': type.name,
      'app': app.name,
      'createdAt': createdAt,
      'accepted': accepted,
      'acceptedUserId': acceptedUserId,
      'clubId': clubId,
      'relatedEntityId': relatedEntityId,
      'acceptedAt': acceptedAt,
      'status': status,
    };
  }

  AppInvite copyWith({
    String? inviterId,
    String? inviterEmail,
    String? inviteeEmail,
    InviteType? type,
    App? app,
    DateTime? createdAt,
    bool? accepted,
    String? acceptedUserId,
    String? clubId,
    String? relatedEntityId,
    DateTime? acceptedAt,
    String? status,
  }) {
    return AppInvite(
      id: id,
      inviterId: inviterId ?? this.inviterId,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      type: type ?? this.type,
      app: app ?? this.app,
      createdAt: createdAt ?? this.createdAt,
      accepted: accepted ?? this.accepted,
      acceptedUserId: acceptedUserId ?? this.acceptedUserId,
      clubId: clubId ?? this.clubId,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      status: status ?? this.status,
    );
  }
}

extension AppInviteOtherPartyUser on AppInvite {
  /// Returns the *other AppUser* involved in this invite.
  ///
  /// Uses UserService to fetch the user document.
  ///
  /// Returns:
  /// - AppUser if the other user can be resolved
  /// - null if the invite is incomplete or user is not found
  Future<AppUser?> otherPartyUser({
    required String currentUserId,
    required UserRepository userRepo,
  }) async {
    String? otherId;

    // User is the inviter
    if (inviterId == currentUserId) {
      otherId = acceptedUserId;
    }
    // User is the accepted user
    else if (acceptedUserId == currentUserId) {
      otherId = inviterId;
    }

    // No valid match or missing ID
    if (otherId == null || otherId.isEmpty) return null;

    return userRepo.getUserDocument(otherId);
  }
}

extension AppInviteStatus on AppInvite {
  /// Not yet responded to
  bool get isPending => accepted == null;

  /// Explicitly accepted
  bool get isAccepted => accepted == true;

  /// Explicitly denied / revoked
  bool get isDenied => accepted == false;
}
