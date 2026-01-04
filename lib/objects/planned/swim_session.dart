import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/objects/planned/set_item.dart';
import 'package:swim_apps_shared/objects/planned/swim_set.dart';
import 'package:swim_apps_shared/objects/planned/swim_set_config.dart';
import 'package:swim_apps_shared/swim_apps_shared.dart';

import '../stroke.dart';

class SwimSession {
  String? id;
  String? title;
  String? coachId;
  String? coachName;
  String? clubId;
  SessionSlot sessionSlot;
  List<SessionSetConfiguration> setConfigurations;
  List<SwimSet> sets; // Holds all SwimSet objects for this swim_session
  TrainingFocus? trainingFocus;
  List<String> assignedSwimmerIds;
  List<String> assignedGroupIds;
  String? overallSessionGoal;
  String? sessionNotes;
  DateTime? startDate;
  DateTime createdAt;
  DateTime? updatedAt;
  DistanceUnit distanceUnit;
  SessionType? sessionType;

  SwimSession({
    this.id,
    this.title,
    this.startDate,
    this.coachId,
    this.coachName,
    required this.sessionSlot,
    required this.setConfigurations,
    required this.sets,
    required this.clubId,
    this.trainingFocus,
    this.overallSessionGoal,
    this.sessionNotes,
    required this.createdAt,
    this.updatedAt,
    this.distanceUnit = DistanceUnit.meters,
    this.sessionType,
    this.assignedSwimmerIds = const [],
    this.assignedGroupIds = const [],
  });

  // --- GETTERS FOR CALCULATED PROPERTIES ---

  /// Calculates the total distance of the swim_session.
  int get totalDistance {
    return setConfigurations.fold<int>(0, (int sum, config) {
      final set = sets.firstWhereOrNull((s) => s.setId == config.swimSetId);
      final setDistance = set?.totalSetDistance ?? 0;
      return sum + (setDistance * config.repetitions);
    });
  }

  /// Calculates the total estimated duration of the swim_session.
  Duration get totalDuration {
    final totalSeconds = setConfigurations.fold<int>(0, (int sum, config) {
      final set = sets.firstWhereOrNull((s) => s.setId == config.swimSetId);
      final setDurationSeconds = set?.totalSetDurationEstimated?.inSeconds ?? 0;
      return sum + (setDurationSeconds * config.repetitions);
    });
    return Duration(seconds: totalSeconds);
  }

  /// Generates a list of unique equipment required for the swim_session.
  List<EquipmentType> get requiredEquipment {
    final equipmentSet = <EquipmentType>{};
    for (var set in sets) {
      for (var item in set.items) {
        equipmentSet.addAll(item.equipment ?? []);
      }
    }
    return equipmentSet.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Helper for calculating distance by a given condition.
  int _calculateDistanceBy(bool Function(SetItem) predicate) {
    return setConfigurations.fold<int>(0, (int sum, config) {
      final set = sets.firstWhereOrNull((s) => s.setId == config.swimSetId);
      int setDistance = 0;
      if (set != null) {
        for (var item in set.items) {
          if (predicate(item)) {
            setDistance += item.itemDistance ?? 0;
          }
        }
      }
      return sum + (setDistance * config.repetitions);
    });
  }

  // --- Stroke and Equipment Distance Getters ---

  int get totalDistanceButterfly =>
      _calculateDistanceBy((item) => item.stroke == Stroke.butterfly);

  int get totalDistanceBackstroke =>
      _calculateDistanceBy((item) => item.stroke == Stroke.backstroke);

  int get totalDistanceBreaststroke =>
      _calculateDistanceBy((item) => item.stroke == Stroke.breaststroke);

  int get totalDistanceFreestyle =>
      _calculateDistanceBy((item) => item.stroke == Stroke.freestyle);

  int get totalDistanceWithFins => _calculateDistanceBy(
        (item) => item.equipment?.contains(EquipmentType.fins) ?? false,
      );

  int get totalDistanceWithPaddles => _calculateDistanceBy(
        (item) => item.equipment?.contains(EquipmentType.paddles) ?? false,
      );

  // --- SERIALIZATION ---

  factory SwimSession.fromJson(String docId, Map<String, dynamic> json) {
    // Helper to safely parse DateTime from various Firestore types.
    DateTime? parseFirestoreTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    // Helper to safely get enum from string name.
    T? getEnumFromString<T>(List<T> values, String? name) {
      if (name == null) return null;
      return values.firstWhereOrNull((v) => (v as Enum).name == name);
    }

    final setConfigs = (json['setConfigurations'] as List<dynamic>?)
            ?.map(
              (configJson) => SessionSetConfiguration.fromJson(
                configJson as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];

    final swimSets = setConfigs
        .where((config) => config.swimSet != null)
        .map((config) => config.swimSet!)
        .toList();

    return SwimSession(
      id: docId,
      title: json['title'],
      startDate: parseFirestoreTimestamp(json['date']),
      coachId: json['coachId'],
      coachName: json['coachName'],
      sessionSlot: getEnumFromString(SessionSlot.values, json['sessionSlot']) ??
          SessionSlot.undefined,
      setConfigurations: setConfigs,
      sets: swimSets,
      // Populate the new `sets` list
      overallSessionGoal: json['overallSessionGoal'],
      clubId: json['clubId'] ?? 'clubId',
      sessionNotes: json['sessionNotes'],
      createdAt: parseFirestoreTimestamp(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreTimestamp(json['updatedAt']),
      trainingFocus: json['trainingFocus'] != null
          ? TrainingFocusFactory.fromName(json['trainingFocus'])
          : TrainingFocusFactory.fromType(TrainingFocusType.mixed),
      distanceUnit:
          getEnumFromString(DistanceUnit.values, json['distanceUnit']) ??
              DistanceUnit.meters,
      sessionType: getEnumFromString(SessionType.values, json['sessionType']),
      assignedSwimmerIds: List<String>.from(json['assignedSwimmerIds'] ?? []),
      assignedGroupIds: List<String>.from(json['assignedGroupIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'coachId': coachId,
      'coachName': coachName,
      'sessionSlot': sessionSlot.name,
      'setConfigurations': setConfigurations.map((c) => c.toJson()).toList(),
      'assignedSwimmerIds': assignedSwimmerIds,
      'assignedGroupIds': assignedGroupIds,
      'overallSessionGoal': overallSessionGoal,
      'sessionNotes': sessionNotes,
      if (trainingFocus != null) 'trainingFocus': trainingFocus?.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'distanceUnit': distanceUnit.name,
      if (sessionType != null) 'sessionType': sessionType!.name,

      // Store calculated totals for querying and quick display in lists
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inSeconds,
      'requiredEquipment': requiredEquipment.map((e) => e.name).toList(),
    };
  }

  SwimSession copyWith({
    ValueGetter<String?>? id,
    ValueGetter<String?>? title,
    ValueGetter<DateTime?>? date,
    ValueGetter<String?>? coachId,
    ValueGetter<String?>? coachName,
    ValueGetter<String?>? clubId,
    SessionSlot? sessionSlot,
    List<SessionSetConfiguration>? setConfigurations,
    List<SwimSet>? sets,
    List<String>? assignedSwimmerIds,
    List<String>? assignedGroupIds,
    ValueGetter<String?>? overallSessionGoal,
    ValueGetter<String?>? sessionNotes,
    DateTime? createdAt,
    ValueGetter<DateTime?>? updatedAt,
    DistanceUnit? distanceUnit,
    ValueGetter<SessionType?>? sessionType,
  }) {
    return SwimSession(
      id: id != null ? id() : this.id,
      title: title != null ? title() : this.title,
      startDate: date != null ? date() : this.startDate,
      coachId: coachId != null ? coachId() : this.coachId,
      coachName: coachName != null ? coachName() : this.coachName,
      sessionSlot: sessionSlot ?? this.sessionSlot,
      setConfigurations: setConfigurations ?? this.setConfigurations,
      sets: sets ?? this.sets,
      assignedSwimmerIds: assignedSwimmerIds ?? this.assignedSwimmerIds,
      assignedGroupIds: assignedGroupIds ?? this.assignedGroupIds,
      clubId: clubId != null ? clubId() : this.clubId,
      overallSessionGoal: overallSessionGoal != null
          ? overallSessionGoal()
          : this.overallSessionGoal,
      sessionNotes: sessionNotes != null ? sessionNotes() : this.sessionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt != null ? updatedAt() : this.updatedAt,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      sessionType: sessionType != null ? sessionType() : this.sessionType,
    );
  }
}

enum SessionType {
  aerobicCapacity,
  endurance,
  speed,
  speedEndurance,
  recovery,
  technique,
  racePace,
  fixed,
  mix,
}
