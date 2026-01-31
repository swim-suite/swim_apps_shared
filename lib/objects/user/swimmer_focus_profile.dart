import '../stroke.dart';
import 'event_specialization.dart';

class SwimmerFocusProfile {
  String id;
  String swimmerId;
  String clubId;
  String coachId;
  String swimmerName;
  EventSpecialization eventSpecialization;
  List<Stroke> focusStrokes;
  String? longTermGoal; // Optional field to describe general goal

  SwimmerFocusProfile({
    required this.id,
    required this.swimmerId,
    required this.swimmerName,
    required this.coachId,
    required this.clubId,
    required this.eventSpecialization,
    required this.focusStrokes,
    this.longTermGoal,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'swimmerId': swimmerId,
    'swimmerName': swimmerName,
    'coachId': coachId,
    'clubId': clubId,
    'eventSpecializationName': eventSpecialization.name,
    'focusStrokes': focusStrokes.map((s) => s.name).toList(),
    if (longTermGoal != null) 'longTermGoal': longTermGoal,
  };

  factory SwimmerFocusProfile.fromJson(Map<String, dynamic> json) {
    return SwimmerFocusProfile(
      id: json['id'] ?? '',
      swimmerId: json['swimmerId'] ?? '',
      swimmerName: json['swimmerName'] ?? '',
      coachId: json['coachId'] ?? '',
      clubId: json['clubId'] ?? '',
      eventSpecialization:
      EventSpecialization.fromString(json['eventSpecializationName']),
      focusStrokes: (json['focusStrokes'] as List<dynamic>? ?? [])
          .map((name) => Stroke.fromString(name))
          .whereType<Stroke>()
          .toList(),
      longTermGoal: json['longTermGoal'],
    );
  }
  SwimmerFocusProfile copyWith({
    String? id,
    String? swimmerId,
    String? swimmerName,
    String? coachId,
    String? clubId,
    EventSpecialization? eventSpecialization,
    List<Stroke>? focusStrokes,
    String? longTermGoal,
  }) {
    return SwimmerFocusProfile(
      id: id ?? this.id,
      swimmerId: swimmerId ?? this.swimmerId,
      swimmerName: swimmerName ?? this.swimmerName,
      coachId: coachId ?? this.coachId,
      clubId: clubId ?? this.clubId,
      eventSpecialization:
      eventSpecialization ?? this.eventSpecialization,
      focusStrokes: focusStrokes ?? List<Stroke>.from(this.focusStrokes),
      longTermGoal: longTermGoal ?? this.longTermGoal,
    );
  }

}
