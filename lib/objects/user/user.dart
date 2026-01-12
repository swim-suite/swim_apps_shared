import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'coach.dart';
import 'swimmer.dart';
import 'user_types.dart';

abstract class AppUser {
  String id;
  String name;
  String? lastName;
  String email;
  String? photoUrl;
  UserType userType;
  String? profilePicturePath;
  DateTime? registerDate;
  DateTime? updatedAt;
  String? clubId;
  String? creatorId;

  bool isBetaUser;
  bool isReviewer;

  /// ✅ New app flags
  bool isSwimCoachSupportUser;
  bool isSwimAnalyzerProUser;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    this.photoUrl,
    this.lastName,
    this.profilePicturePath,
    this.registerDate,
    this.updatedAt,
    this.clubId,
    this.creatorId,
    this.isSwimCoachSupportUser = false,
    this.isSwimAnalyzerProUser = false,
    this.isBetaUser = false,
    this.isReviewer = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastName': lastName,
      'email': email,
      'userType': userType.name,
      'photoUrl': photoUrl,
      if (clubId != null) 'clubId': clubId,
      if (profilePicturePath != null) 'profilePicturePath': profilePicturePath,
      if (registerDate != null)
        'registerDate': Timestamp.fromDate(registerDate!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (creatorId != null) 'creatorId': creatorId,

      /// ✅ store app flags
      'isSwimCoachSupportUser': isSwimCoachSupportUser,
      'isSwimAnalyzerProUser': isSwimAnalyzerProUser,
    };
  }

  factory AppUser.fromJson(String docId, Map<String, dynamic> json) {
    if (json.isEmpty) {
      debugPrint("⚠️ Empty user document for $docId");
      return Swimmer(id: docId, name: 'Unknown', email: '');
    }

    UserType detectedUserType = _getUserTypeFromString(json['userType']);
    json['userType'] = detectedUserType.name;

    final bool usedCoachApp = json['isSwimCoachSupportUser'] as bool? ?? false;
    final bool usedAnalyzerApp =
        json['isSwimAnalyzerProUser'] as bool? ?? false;
    final bool isReviewer = json['isReviewer'] as bool? ?? false;

    final bool isBetaUser = json['isBetaUser'] as bool? ?? false;

    switch (detectedUserType) {
      case UserType.coach:
        return Coach.fromJson(docId, json).copyWith(
          isSwimCoachSupportUser: usedCoachApp,
          isSwimAnalyzerProUser: usedAnalyzerApp,
          isBetaUser: isBetaUser,
            isReviewer: isReviewer);
      case UserType.swimmer:
        return Swimmer.fromJson(docId, json).copyWith(
          isSwimCoachSupportUser: usedCoachApp,
          isSwimAnalyzerProUser: usedAnalyzerApp,
          isBetaUser: isBetaUser,
        );
    }
  }

  static UserType _getUserTypeFromString(String? value) {
    if (value == null) return UserType.swimmer;
    return UserType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserType.swimmer,
    );
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? lastName,
    String? email,
    String? profilePicturePath,
    DateTime? registerDate,
    DateTime? updatedAt,
    String? clubId,
    String? creatorId,
    UserType userType,
    bool? isSwimCoachSupportUser,
    bool? isSwimAnalyzerProUser,
  });
}
