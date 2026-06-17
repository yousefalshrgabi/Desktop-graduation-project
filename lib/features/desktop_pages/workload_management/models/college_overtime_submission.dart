import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeOvertimeSubmission {
  const CollegeOvertimeSubmission({
    required this.id,
    required this.collegeName,
    required this.term,
    required this.type, // 'overtime' or 'parallel'
    required this.status,
    required this.createdByUid,
    this.rejectionReason,
    this.createdAt,
    this.entries = const [],
  });

  final String id;
  final String collegeName;
  final String term;
  final String type; 
  final String status;
  final String createdByUid;
  final String? rejectionReason;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> entries;

  Map<String, dynamic> toMap() {
    return {
      'collegeName': collegeName,
      'term': term,
      'type': type,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'entries': entries,
    };
  }

  factory CollegeOvertimeSubmission.fromMap(Map<String, dynamic> map, String docId) {
    return CollegeOvertimeSubmission(
      id: docId,
      collegeName: map['collegeName'] as String? ?? '',
      term: map['term'] as String? ?? '',
      type: map['type'] as String? ?? 'overtime',
      status: map['status'] as String? ?? 'pending_dean',
      createdByUid: map['createdByUid'] as String? ?? '',
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      entries: (map['entries'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}
