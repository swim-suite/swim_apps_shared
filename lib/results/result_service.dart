import 'package:cloud_firestore/cloud_firestore.dart';
import 'set_item_result.dart';

class ResultService {
  final FirebaseFirestore _db;

  ResultService(this._db);

  CollectionReference<Map<String, dynamic>> _resultsCol(
      String clubId,
      String sessionId,
      ) {
    return _db
        .collection('swimClubs')
        .doc(clubId)
        .collection('sessions')
        .doc(sessionId)
        .collection('setItemResults');
  }

  Future<void> saveResult({
    required String clubId,
    required SetItemResult result,
  }) async {
    final col = _resultsCol(clubId, result.sessionId);
    await col.doc(result.resultId).set(result.toJson(), SetOptions(merge: true));
  }

  Future<List<SetItemResult>> getResultsForSetItem({
    required String clubId,
    required String sessionId,
    required String setItemId,
    String? swimmerId,
  }) async {
    var q = _resultsCol(clubId, sessionId)
        .where('setItemId', isEqualTo: setItemId);

    if (swimmerId != null) {
      q = q.where('swimmerId', isEqualTo: swimmerId);
    }

    final snap = await q.get();
    return snap.docs
        .map((d) => SetItemResult.fromJson(d.data()))
        .toList();
  }

  Future<List<SetItemResult>> getResultsForTestKey({
    required String clubId,
    required String testKey,
    String? swimmerId,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collectionGroup('setItemResults')
        .where('testKey', isEqualTo: testKey)
        .orderBy('recordedAt', descending: true)
        .limit(limit);

    if (swimmerId != null) {
      q = q.where('swimmerId', isEqualTo: swimmerId);
    }

    final snap = await q.get();
    return snap.docs
        .map((d) => SetItemResult.fromJson(d.data()))
        .toList();
  }

  /// Basic stats for a single test key & swimmer.
  Future<Map<String, dynamic>> getTestStatsForSwimmer({
    required String clubId,
    required String testKey,
    required String swimmerId,
  }) async {
    final results = await getResultsForTestKey(
      clubId: clubId,
      testKey: testKey,
      swimmerId: swimmerId,
      limit: 200,
    );

    if (results.isEmpty) {
      return {
        'count': 0,
        'bestTime': null,
        'latestTime': null,
        'averageTime': null,
      };
    }

    final valid = results.where((r) => r.time != null).toList();
    if (valid.isEmpty) {
      return {
        'count': results.length,
        'bestTime': null,
        'latestTime': null,
        'averageTime': null,
      };
    }

    valid.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final latest = valid.last;

    final best = valid.reduce((a, b) {
      if (a.time!.inMilliseconds <= b.time!.inMilliseconds) return a;
      return b;
    });

    final avgMs = valid
        .map((r) => r.time!.inMilliseconds)
        .reduce((a, b) => a + b) ~/
        valid.length;

    return {
      'count': results.length,
      'bestTime': best.time,
      'latestTime': latest.time,
      'averageTime': Duration(milliseconds: avgMs),
      'firstDate': valid.first.recordedAt,
      'latestDate': latest.recordedAt,
    };
  }
}
