import 'package:cloud_firestore/cloud_firestore.dart';

mixin AnalyzableBase {
  String? id;
  String? coachId;         // creator
  String? swimmerId;       // optional linked profile
  String? swimmerName;     // optional tagged name (when swimmerId == null)
  String? clubId;
  DateTime? createdAt;

  Map<String, dynamic> analyzableBaseToJson() => {
    if (id != null) 'id': id,
    if (coachId != null) 'coachId': coachId,
    if (swimmerId != null) 'swimmerId': swimmerId,
    if (swimmerName != null) 'swimmerName': swimmerName,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  void loadAnalyzableBase(Map<String, dynamic> data, String docId) {
    id = docId;
    coachId = data['coachId'];
    swimmerId = data['swimmerId'];
    swimmerName = data['swimmerName'];
    createdAt = DateTime.tryParse(data['createdAt'] ?? '') ??
        (data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null);
  }
}
