import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:swim_apps_shared/objects/user/swimmer.dart';

import '../objects/analyzes/race_analyze.dart';
import '../objects/analyzes/start_analyze.dart';
import 'base_repository.dart';

class AnalyzesRepository extends BaseRepository {
  final FirebaseFirestore _db;

  AnalyzesRepository(this._db);

  // --- Collection References with Robust Converters ---

  /// Helper to create a collection reference with a converter that handles
  /// data parsing errors gracefully.
  CollectionReference<T> _getCollection<T>({
    required String path,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromFirestore,
    required Map<String, Object?> Function(T, SetOptions?) toFirestore,
  }) {
    return _db.collection(path).withConverter<T>(
      fromFirestore: (snapshot, _) {
        // This try-catch block handles potential errors during data parsing.
        try {
          if (!snapshot.exists || snapshot.data() == null) {
            // This is a valid case where a document might not exist.
            // We throw an exception to signal that parsing cannot proceed.
            throw Exception(
              "Document ${snapshot.id} in '$path' does not exist or has null data.",
            );
          }
          // Attempt to parse the document using the provided fromFirestore function.
          return fromFirestore(snapshot);
        } catch (e, s) {
          // --- Error Handling Improvement ---
          // Instead of logging to an external service, we print a detailed
          // error message to the debug console, which is useful during development.
          final errorMsg =
              "Failed to parse document ${snapshot.id} in '$path'. Error: $e";
          debugPrint("🔥 [Firestore Parser Error] $errorMsg\n$s");

          // Re-throw the error. This is crucial as it allows the calling code
          // (like `_fetchFromQuery` or a Stream `.map`) to catch this specific
          // failure and skip the corrupted document without crashing.
          rethrow;
        }
      },
      toFirestore: toFirestore,
    );
  }

  // --- Race Analyses ---
  CollectionReference<RaceAnalyze> get _racesRef =>
      _getCollection<RaceAnalyze>(
        path: 'racesAnalyzes',
        fromFirestore: (snapshot) => RaceAnalyze.fromFirestore(snapshot),
        toFirestore: (race, _) => race.toJson(),
      );

  // --- Off The Block Analyses ---
  CollectionReference<StartAnalyze> get _offTheBlockRef =>
      _getCollection<StartAnalyze>(
        path: 'offTheBlockAnalyzes',
        fromFirestore: (snapshot) =>
            StartAnalyze.fromMap(snapshot.data()!, snapshot.id),
        toFirestore: (analysis, _) => analysis.toMap(),
      );

  // --- Generic Data Fetching Logic ---

  /// Generic helper to execute a Firestore query and handle potential errors.
  /// It safely parses each document and skips any that fail conversion.
  Future<List<T>> _fetchFromQuery<T>(
      Query<T> query,
      String operationDescription,
      ) async {
    try {
      final snapshot = await query.get();
      // Safely parse each document, skipping any that fail.
      return _parseDocsSafely(snapshot.docs, operationDescription);
    } catch (e, s) {
      // --- Error Handling Improvement ---
      // This catches errors from the Firestore query itself (e.g., network issues, permission denied).
      debugPrint("🔥 Firestore Query Error in '$operationDescription': $e\n$s");
      return []; // Return an empty list to ensure the app remains stable.
    }
  }

  /// Helper to safely parse a list of documents, skipping any that fail.
  List<T> _parseDocsSafely<T>(List<QueryDocumentSnapshot<T>> docs, String context) {
    final List<T> results = [];
    for (final doc in docs) {
      try {
        results.add(doc.data());
      } catch (e) {
        // The error is already logged by the `fromFirestore` converter.
        // This just provides context for which document was skipped.
        debugPrint(
          "Skipping document ${doc.id} in '$context' due to a parsing error.",
        );
      }
    }
    return results;
  }

  // --- CRUD Methods for Off The Block Analyses ---

  Future<DocumentReference<StartAnalyze>> saveOffTheBlock(
      StartAnalyze analysisData,
      ) {
    // This is a write operation, which is typically safe unless there are
    // security rule violations, which will be caught by the calling UI layer.
    return _offTheBlockRef.add(analysisData);
  }

  Future<List<StartAnalyze>> getOffTheBlockAnalysesForUser(
      String userId,
      ) {
    final query = _offTheBlockRef
        .where('swimmerId', isEqualTo: userId)
        .orderBy('date', descending: true);
    return _fetchFromQuery(
      query,
      'getOffTheBlockAnalysesForUser(userId: $userId)',
    );
  }

  Stream<List<StartAnalyze>> getStreamOfOffTheBlockAnalysesForUser(
      String userId,
      ) {
    return _offTheBlockRef
        .where('swimmerId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
    // --- Refactoring for Simplicity ---
    // The redundant try-catch is removed. The parsing logic is now handled
    // by the `_parseDocsSafely` helper, which leverages the converter's error handling.
        .map((snapshot) => _parseDocsSafely(snapshot.docs, 'stream for user $userId'));
  }

  Stream<List<StartAnalyze>> getStreamOfOffTheBlockAnalysesForClub(
      String clubId,
      ) {
    return _offTheBlockRef
        .where('clubId', isEqualTo: clubId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => _parseDocsSafely(snapshot.docs, 'stream for club $clubId'));
  }

  Future<List<StartAnalyze>> getOffTheBlockAnalysesByIds({
    required List<String> analysisIds,
  }) async {
    if (analysisIds.isEmpty) return [];

    try {
      final chunks = _splitList(analysisIds, 30);
      List<StartAnalyze> allAnalyses = [];

      for (final chunk in chunks) {
        final query = _offTheBlockRef.where(
          FieldPath.documentId,
          whereIn: chunk,
        );
        final snapshot = await query.get();
        // Use the safe parsing helper.
        allAnalyses.addAll(_parseDocsSafely(snapshot.docs, 'getOffTheBlockAnalysesByIds'));
      }

      // Reorder the results to match the input ID list.
      final analysisMap = {for (var a in allAnalyses) a.id: a};
      return analysisIds
          .map((id) => analysisMap[id])
          .whereType<StartAnalyze>()
          .toList();
    } catch (e, s) {
      debugPrint("🔥 Error in getOffTheBlockAnalysesByIds: $e\n$s");
      return [];
    }
  }

  /// Splits a list into smaller chunks, useful for Firestore 'whereIn' queries.
  List<List<T>> _splitList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }

  Future<StartAnalyze?> getOffTheBlockAnalysis(
      String analysisId,
      ) async {
    try {
      final doc = await _offTheBlockRef.doc(analysisId).get();
      // The `data()` call will trigger the safe `fromFirestore` converter.
      return doc.data();
    } catch (e, s) {
      debugPrint("🔥 Error in getOffTheBlockAnalysis(id: $analysisId): $e\n$s");
      return null;
    }
  }

  Future<void> updateOffTheBlockAnalysis(StartAnalyze analysis) =>
      _offTheBlockRef.doc(analysis.id).update(analysis.toMap());

  Future<void> deleteOffTheBlockAnalysis(String analysisId) =>
      _offTheBlockRef.doc(analysisId).delete();

  // --- CRUD Methods for Race Analyses ---

  Future<List<RaceAnalyze>> getRacesForUser(String userId) {
    final query = _racesRef
        .where('swimmerId', isEqualTo: userId)
        .orderBy('raceDate', descending: true);
    return _fetchFromQuery(query, 'getRacesForUser(userId: $userId)');
  }

  Stream<List<RaceAnalyze>> getStreamOfRacesForUser(String userId) {
    return _racesRef
        .where('swimmerId', isEqualTo: userId)
        .orderBy('raceDate', descending: true)
        .snapshots()
        .map((snapshot) => _parseDocsSafely(snapshot.docs, 'race stream for user $userId'));
  }

  Stream<List<RaceAnalyze>> getStreamOfRacesForClub(String clubId) {
    return _racesRef
        .where('clubId', isEqualTo: clubId)
        .orderBy('raceDate', descending: true)
        .snapshots()
        .map((s) => _parseDocsSafely(s.docs, 'club race stream'));
  }


  Future<RaceAnalyze?> getRace(String raceId) async {
    try {
      final DocumentSnapshot<RaceAnalyze> doc = await _racesRef
          .doc(raceId)
          .get();
      return doc.data();
    } catch (e, s) {
      debugPrint("🔥 Error in getRace(id: $raceId): $e\n$s");
      return null;
    }
  }

  ///Get the latest race analyze by Swimmer Id
  Future<RaceAnalyze?> getLatestRaceAnalysis({required Swimmer swimmer}) async {
    try {
      final QuerySnapshot<RaceAnalyze> snapshot = await _racesRef
          .where('swimmerId', isEqualTo: swimmer.id)
          .orderBy('raceDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Return the model from the first (latest) doc
      return snapshot.docs.first.data();
    } catch (e, s) {
      debugPrint(
          "🔥 Error in getLatestRaceAnalysis(swimmerId: ${swimmer.id}): $e\n$s");
      return null;
    }
  }


  Future<void> addRace(RaceAnalyze race) => _racesRef.add(race);

  Future<void> updateRace(RaceAnalyze race) =>
      _racesRef.doc(race.id).update(race.toJson());

  Future<void> deleteRace(String raceId) => _racesRef.doc(raceId).delete();

  Future<List<RaceAnalyze>> getRacesByRequestIds(
    List<String> requestIds,
  ) async {
    if (requestIds.isEmpty) return [];

    final chunks = _splitList(requestIds, 10); // 🔥 MUST BE 10
    final List<RaceAnalyze> all = [];

    for (final chunk in chunks) {
      final query = _racesRef.where(
        'raceAnalyzeRequestId',
        whereIn: chunk,
      );

      final snapshot = await query.get();

      all.addAll(
        _parseDocsSafely(snapshot.docs, 'getRacesByRequestIds'),
      );
    }

    return all;
  }
}
