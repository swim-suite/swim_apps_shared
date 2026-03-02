import 'package:cloud_firestore/cloud_firestore.dart';

mixin AnalyzableBase {
  String? id;
  String? coachId; // creator
  String? swimmerId; // optional linked profile
  String? swimmerName; // optional tagged name (when swimmerId == null)
  String? clubId;
  DateTime? createdAt;

  Map<String, dynamic> analyzableBaseToJson() => {
    if (id != null) 'id': id,
    if (coachId != null) 'coachId': coachId,
    if (swimmerId != null) 'swimmerId': swimmerId,
    if (swimmerName != null) 'swimmerName': swimmerName,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  static String? _parseString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is num || raw is bool) return raw.toString();
    if (raw is Map) {
      const preferredKeys = ['name', 'value', 'id', 'uid'];
      for (final key in preferredKeys) {
        final parsed = _parseString(raw[key]);
        if (parsed != null) return parsed;
      }
      for (final value in raw.values) {
        final parsed = _parseString(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Map) {
      final secondsRaw = raw['_seconds'] ?? raw['seconds'];
      if (secondsRaw is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (secondsRaw * 1000).round(),
          isUtc: true,
        );
      }

      final millisecondsRaw =
          raw['milliseconds'] ?? raw['millis'] ?? raw['ms'] ?? raw['value'];
      if (millisecondsRaw is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          millisecondsRaw.round(),
          isUtc: true,
        );
      }

      if (millisecondsRaw is String) {
        final parsed = num.tryParse(millisecondsRaw.trim());
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            parsed.round(),
            isUtc: true,
          );
        }
      }
    }
    return null;
  }

  void loadAnalyzableBase(Map<String, dynamic> data, String docId) {
    id = docId;
    coachId = _parseString(data['coachId']);
    swimmerId = _parseString(data['swimmerId']);
    swimmerName = _parseString(data['swimmerName']);
    clubId = _parseString(data['clubId']);
    createdAt = _parseDate(data['createdAt']);
  }
}
