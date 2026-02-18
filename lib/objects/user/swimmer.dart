import 'package:swim_apps_shared/objects/user/user.dart';
import 'package:swim_apps_shared/objects/user/user_types.dart';
import 'package:swim_apps_shared/objects/stroke.dart';

class Swimmer extends AppUser {
  String? headCoachId;
  String? secondCoachId;
  String? thirdCoachId;
  List<String>? memberOfTeams;
  final List<String> mainEventIds;
  final Stroke? primaryStroke;

  Swimmer({
    required super.id,
    required super.name,
    required super.email,
    super.lastName,
    super.profilePicturePath,
    super.photoUrl,
    super.registerDate,
    super.clubId,
    super.updatedAt,
    this.memberOfTeams,
    this.primaryStroke,
    super.creatorId,
    this.secondCoachId,
    this.thirdCoachId,
    this.mainEventIds = const [],
  }) : super(userType: UserType.swimmer);

  factory Swimmer.fromJson(String docId, Map<String, dynamic> json) {
    // Defensive cast for list/map variations (web safe)
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return List<String>.from(value.map((e) => e.toString()));
      }
      if (value is Map) return value.values.map((e) => e.toString()).toList();
      return [];
    }

    return Swimmer(
      id: docId,
      name: json['name'] as String? ?? 'Swimmer',
      lastName: json['lastName'] as String?,
      email: json['email'] as String? ?? '',
      profilePicturePath: json['profilePicturePath'] as String?,
      photoUrl: json['photoUrl'] as String?,
      registerDate: AppUser.parseDateTime(json['registerDate']),
      updatedAt: AppUser.parseDateTime(json['updatedAt']),
      clubId: json['clubId'] as String?,
      memberOfTeams: parseStringList(json['memberOfTeams']),
      creatorId: json['creatorId'] as String?,
      secondCoachId: json['secondCoachId'] as String?,
      thirdCoachId: json['thirdCoachId'] as String?,
      primaryStroke: Stroke.fromString(json['primaryStroke'] as String?),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      if (creatorId != null) 'coachCreatorId': creatorId,
      if (secondCoachId != null) 'secondCoachId': secondCoachId,
      if (thirdCoachId != null) 'thirdCoachId': thirdCoachId,
      if (memberOfTeams != null) 'memberOfTeams': memberOfTeams,
      if (mainEventIds.isNotEmpty) 'mainEventIds': mainEventIds,
      if (primaryStroke != null) 'primaryStroke': primaryStroke!.name,
    });
    return json;
  }

  @override
  Swimmer copyWith({
    String? id,
    String? name,
    String? lastName,
    String? email,
    String? profilePicturePath,
    String? photoUrl,
    DateTime? registerDate,
    DateTime? updatedAt,
    String? clubId,
    String? creatorId,
    UserType? userType, // ✅ added to match AppUser
    bool? isSwimCoachSupportUser,
    bool? isSwimAnalyzerProUser,
    // ✅ Swimmer-specific fields
    String? headCoachId,
    String? secondCoachId,
    String? thirdCoachId,
    List<String>? memberOfTeams,
    List<String>? mainEventIds,
    Stroke? primaryStroke,
    bool? isBetaUser,
  }) {
    final swimmer = Swimmer(
      id: id ?? this.id,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      photoUrl: photoUrl ?? this.photoUrl,
      registerDate: registerDate ?? this.registerDate,
      updatedAt: updatedAt ?? this.updatedAt,
      clubId: clubId ?? this.clubId,
      creatorId: creatorId ?? this.creatorId,
      memberOfTeams: memberOfTeams ?? this.memberOfTeams,
      mainEventIds: mainEventIds ?? this.mainEventIds,
      primaryStroke: primaryStroke ?? this.primaryStroke,
      secondCoachId: secondCoachId ?? this.secondCoachId,
      thirdCoachId: thirdCoachId ?? this.thirdCoachId,
      // Note: headCoachId is not in constructor but preserved below
    );

    // ✅ Assign inherited flags AFTER constructor
    swimmer.isSwimCoachSupportUser =
        isSwimCoachSupportUser ?? this.isSwimCoachSupportUser;
    swimmer.isSwimAnalyzerProUser =
        isSwimAnalyzerProUser ?? this.isSwimAnalyzerProUser;

    swimmer.isBetaUser = isBetaUser ?? false;
    // ✅ Preserve additional field
    swimmer.headCoachId = headCoachId ?? this.headCoachId;

    return swimmer;
  }
}
