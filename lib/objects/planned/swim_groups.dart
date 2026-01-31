import 'package:cloud_firestore/cloud_firestore.dart';

class SwimGroup {
  String? id; // Firestore document ID
  String name;
  String? description;
  String coachId; // ID of the coach who owns this group
  String? coachName; // Optional: denormalized coach name for easier display
  String? clubId;
  List<String> swimmerIds; // List of User UIDs (swimmers)
  Timestamp? createdAt;
  Timestamp? updatedAt;

  SwimGroup({
    this.id,
    required this.name,
    this.description,
    required this.coachId,
    this.coachName,
    this.clubId,
    List<String>? swimmerIds, // Make it optional in constructor
    this.createdAt,
    this.updatedAt,
  }) : swimmerIds = swimmerIds ?? []; // Initialize to empty list if null

  // Factory constructor to create a SwimGroup from embedded JSON
  factory SwimGroup.fromJson(Map<String, dynamic> json) {
    return SwimGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Group',
      description: json['description'] as String?,
      coachId: json['coachId'] as String? ?? '',
      coachName: json['coachName'] as String?,
      clubId: json['clubId'] as String?,
      swimmerIds: (json['swimmerIds'] as List<dynamic>?)
          ?.map((id) => id as String)
          .toList() ??
          [],
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
    );
  }

  // Method to convert a SwimGroup instance to a map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'coachId': coachId,
      'clubId': clubId,
      'coachName': coachName, // Store if you have it
      'swimmerIds': swimmerIds,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(), // Set on create
      'updatedAt': FieldValue.serverTimestamp(), // Always update on save/update
    };
  }

  // Optional: A copyWith method can be useful for updates
  SwimGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? coachId,
    String? clubId,
    String? coachName,
    List<String>? swimmerIds,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool setUpdatedAtToNull =
        false, // Special flag if you want to control timestamp explicitly
  }) {
    return SwimGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coachId: coachId ?? this.coachId,
      clubId: clubId ?? this.clubId,
      coachName: coachName ?? this.coachName,
      swimmerIds: swimmerIds ?? List.from(this.swimmerIds),

      // Create a new list copy
      createdAt: createdAt ?? this.createdAt,
      updatedAt: setUpdatedAtToNull ? null : (updatedAt ?? this.updatedAt),
    );
  }
}
