import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/incentive_entry.dart';

class CollegeWorkloadSubmission {
  const CollegeWorkloadSubmission({
    required this.id,
    required this.collegeName,
    required this.term,
    required this.entries,
    required this.status,
    this.rejectionReason,
    this.createdAt,
    this.createdByUid = '',
  });

  final String id;
  final String collegeName;
  final String term;
  final List<IncentiveEntry> entries;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final String createdByUid;

  Map<String, dynamic> toMap() {
    return {
      'collegeName': collegeName,
      'term': term,
      'entries': entries.map((e) => e.toFirestoreMap()).toList(),
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
    };
  }

  factory CollegeWorkloadSubmission.fromMap(Map<String, dynamic> map, String docId) {
    return CollegeWorkloadSubmission(
      id: docId,
      collegeName: map['collegeName'] as String? ?? '',
      term: map['term'] as String? ?? '',
      entries: (map['entries'] as List<dynamic>? ?? [])
          .map((e) => IncentiveEntry.fromFirestoreMap(e as Map<String, dynamic>))
          .toList(),
      status: map['status'] as String? ?? 'pending_dean',
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdByUid: map['createdByUid'] as String? ?? '',
    );
  }
}

class CollegeWorkloadSubmissionService {
  final _collection = FirebaseFirestore.instance.collection('college_workload_submissions');

  Future<void> submitToDean({
    required String collegeName,
    required String term,
    required List<IncentiveEntry> entries,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final sub = CollegeWorkloadSubmission(
      id: '',
      collegeName: collegeName,
      term: term,
      entries: entries,
      status: 'pending_dean',
      createdByUid: uid,
      createdAt: DateTime.now(),
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

  Stream<List<CollegeWorkloadSubmission>> getSubmissionsByStatus(String status) {
    return _collection
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeWorkloadSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CollegeWorkloadSubmission>> getSubmissionsByCollege(String college) {
    return _collection
        .where('collegeName', isEqualTo: college)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeWorkloadSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CollegeWorkloadSubmission>> getAllSubmissions() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CollegeWorkloadSubmission.fromMap(doc.data(), doc.id))
            .toList());
  }
}
