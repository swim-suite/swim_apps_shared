import 'package:cloud_firestore/cloud_firestore.dart';

class SwimGroup {
  final String id;
  final String name;
  final String coachId;
  final String? description;
  final String? coachName;
  final String? clubId;
  final List<String> swimmerIds;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  SwimGroup({
    required this.id,
    required this.name,
    required this.coachId,
    this.description,
    this.coachName,
    this.clubId,
    List<String>? swimmerIds,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  })  : swimmerIds = swimmerIds ?? const [],
        createdAt = createdAt ?? Timestamp.now(),
        updatedAt = updatedAt ?? Timestamp.now();

  // Embedded JSON → model
  factory SwimGroup.fromJson(Map<String, dynamic> json) {
    return SwimGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Group',
      coachId: json['coachId'] as String? ?? '',
      description: json['description'] as String?,
      coachName: json['coachName'] as String?,
      clubId: json['clubId'] as String?,
      swimmerIds: (json['swimmerIds'] as List<dynamic>?)
          ?.cast<String>() ??
          const [],
      createdAt: json['createdAt'] as Timestamp?,
      updatedAt: json['updatedAt'] as Timestamp?,
    );
  }

  // Model → embedded JSON (NO Firestore sentinels)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coachId': coachId,
      'description': description,
      'coachName': coachName,
      'clubId': clubId,
      'swimmerIds': swimmerIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  SwimGroup copyWith({
    String? name,
    String? description,
    String? coachId,
    String? coachName,
    String? clubId,
    List<String>? swimmerIds,
    Timestamp? updatedAt,
  }) {
    return SwimGroup(
      id: id,
      name: name ?? this.name,
      coachId: coachId ?? this.coachId,
      description: description ?? this.description,
      coachName: coachName ?? this.coachName,
      clubId: clubId ?? this.clubId,
      swimmerIds: swimmerIds ?? List.from(this.swimmerIds),
      createdAt: createdAt,
      updatedAt: updatedAt ?? Timestamp.now(),
    );
  }
}
