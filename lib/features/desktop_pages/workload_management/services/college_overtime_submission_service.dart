import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/college_overtime_submission.dart';

class CollegeOvertimeSubmissionService {
  final _collection = FirebaseFirestore.instance.collection('college_overtime_submissions');

  Future<void> submitToDean({
    required String collegeName,
    required String term,
    required String type,
    required List<Map<String, dynamic>> entries,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sub = CollegeOvertimeSubmission(
      id: '',
      collegeName: collegeName,
      term: term,
      type: type,
      status: 'pending_dean',
      createdByUid: uid,
      createdAt: DateTime.now(),
      entries: entries,
    );
    await _collection.add(sub.toMap());
  }

  Future<void> approveByDean(String id) async {
    await _collection.doc(id).update({
      'status': 'pending_vice_chancellor',
      'rejectionReason': null,
    });
  }

  Future<void> rejectByDean(String id, String reason) async {
    await _collection.doc(id).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
  }

  Future<void> approveByDeanship(String id) async {
    await _collection.doc(id).update({
      'status': 'approved',
      'rejectionReason': null,
    });
  }

  Future<void> rejectByDeanship(String id, String reason) async {
    await _collection.doc(id).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });
  }

  Stream<List<CollegeOvertimeSubmission>> getSubmissionsByStatus(String status) {
    return _collection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeOvertimeSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CollegeOvertimeSubmission>> getSubmissionsByCollege(String college) {
    return _collection
        .where('collegeName', isEqualTo: college)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeOvertimeSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CollegeOvertimeSubmission>> getAllSubmissions() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeOvertimeSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }
}
