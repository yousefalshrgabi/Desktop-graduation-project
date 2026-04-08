import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String id;
  final String name;
  final String collegeId;
  final String hodId;
  final String createdAt;

  DepartmentModel({
    required this.id,
    required this.name,
    required this.collegeId,
    required this.hodId,
    required this.createdAt,
  });

  /// تنسيق التاريخ فقط بدون وقت
  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  factory DepartmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final createdAtTs = data['createdAt'] as Timestamp?;
    final createdAtStr =
        createdAtTs != null ? _formatDate(createdAtTs.toDate()) : '-';

    return DepartmentModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'غير محدد',
      collegeId: data['collegeId']?.toString() ?? '',
      hodId: data['HODId']?.toString() ?? '',
      createdAt: createdAtStr,
    );
  }
}
