import 'package:cloud_firestore/cloud_firestore.dart';

import 'analysis_request.dart';

class AnalysisRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('analysis_requests');

  // --------------------------------------------------------------------------
  // CREATE
  // --------------------------------------------------------------------------
  Future<String> create(AnalysisRequest request) async {
    final docRef = await _col.add(request.toJson());
    return docRef.id;
  }

  // --------------------------------------------------------------------------
  // READ (ONE)
  // --------------------------------------------------------------------------
  Future<AnalysisRequest?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;

    return AnalysisRequest.fromJson(json: snap.data()!, id: snap.id);
  }

  // --------------------------------------------------------------------------
  // READ (MANY) – for user
  // --------------------------------------------------------------------------
  Future<List<AnalysisRequest>> getForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) => AnalysisRequest.fromJson(json: d.data(), id: d.id))
        .toList();
  }

  // --------------------------------------------------------------------------
  // STREAM (ONE)
  // --------------------------------------------------------------------------
  Stream<AnalysisRequest?> streamById(String id) {
    return _col.doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AnalysisRequest.fromJson(json: snap.data()!, id: snap.id);
    });
  }

  // --------------------------------------------------------------------------
  // STREAM (MANY) – for user
  // --------------------------------------------------------------------------
  Stream<List<AnalysisRequest>> streamForUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AnalysisRequest.fromJson(json: d.data(), id: d.id))
            .toList());
  }

  // --------------------------------------------------------------------------
  // UPDATE
  // --------------------------------------------------------------------------
  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _col.doc(id).update(updates);
  }

  Future<void> setStatus(String id, String status) async {
    await update(id, {'status': status});
  }

  // --------------------------------------------------------------------------
  // DELETE
  // --------------------------------------------------------------------------
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// -------------------------
  ///  STREAM unprocessed
  ///_________________________
  Stream<List<AnalysisRequest>> streamUnprocessed() {
    return _col
        .where('processed', isEqualTo: false)
        .orderBy('createdAt', descending: false) // oldest first
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AnalysisRequest.fromJson(json: d.data(), id: d.id))
            .toList());
  }

  /// -------------------------
  ///  STREAM all by created date
  ///_________________________
  Stream<List<AnalysisRequest>> streamAllByCreatedDate() {
    return _col
        .orderBy('createdAt', descending: false) // oldest first
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AnalysisRequest.fromJson(json: d.data(), id: d.id))
            .toList());
  }

  // --- ADD THIS NEW METHOD ---
  Future<List<AnalysisRequest>> getByEmail(String email) async {
    // 1. Normalize email to avoid case sensitivity issues
    final normalizedEmail = email.trim().toLowerCase();

    // 2. Query Firestore
    // Note: You might need to create an index in Firebase Console for email + createdAt
    final snapshot = await _col
        .where('email', isEqualTo: normalizedEmail)
        .orderBy('createdAt', descending: true)
        .get();

    // 3. Map to your object
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure the ID is passed if your fromJson expects it in the map
      // or if your constructor takes it separately.
      // Based on your model: required this.id
      data['id'] = doc.id;

      return AnalysisRequest.fromJson(json: data, id: doc.id);
    }).toList();
  }
}
