import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeModel {
  final String id;
  final String arName;
  final String enName;
  final String code;
  final String deanId;
  final String createdAt;

  CollegeModel({
    required this.id,
    required this.arName,
    required this.enName,
    required this.code,
    required this.deanId,
    required this.createdAt,
  });

  // دالة مساعدة لتنسيق التاريخ فقط
  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // دالة مساعدة لتحويل بيانات Firestore إلى Object
  factory CollegeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAtString = createdAtTimestamp != null
        ? _formatDateTime(createdAtTimestamp.toDate())
        : '-';

    return CollegeModel(
      id: doc.id,
      arName: data['ar_name']?.toString() ?? 'غير محدد',
      enName: data['en_name']?.toString() ?? 'غير محدد',
      code: data['code']?.toString() ?? 'غير محدد',
      deanId: data['deanId']?.toString() ?? '',
      createdAt: createdAtString,
    );
  }
}
