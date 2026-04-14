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

  /// دالة ذكية لمعالجة التاريخ مهما كان نوع البيانات القادمة من Firestore
  static String _safeParseDate(dynamic value) {
    if (value == null) return '-';

    try {
      // 1. إذا كانت القيمة Timestamp (الوضع الافتراضي)
      if (value is Timestamp) {
        final dt = value.toDate();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }

      // 2. إذا كانت القيمة String (نص تاريخ)
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
        }
        return value; // إذا لم ينجح التحويل، نعيد النص كما هو بدلاً من الانهيار
      }
    } catch (e) {
      return '-';
    }

    return '-';
  }

  // دالة مساعدة لتحويل بيانات SQLite إلى Object
  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    String parsedDate = '-';
    // الانتباه لاستخدام created_at
    if (map['created_at'] != null) {
      DateTime? dt = DateTime.tryParse(map['created_at'].toString());
      if (dt != null) {
        parsedDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else {
        parsedDate = map['created_at'].toString();
      }
    }

    return DepartmentModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'غير محدد',
      // ربط الحقول بأسماء أعمدة SQLite
      collegeId: map['college_id']?.toString() ?? '',
      hodId: map['hod_id']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  factory DepartmentModel.fromFirestore(DocumentSnapshot doc) {
    // التأكد من أن البيانات ليست Null
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DepartmentModel(
      id: doc.id,
      // استخدام toString() للوقاية من أي أخطاء تحويل (Casting)
      name: data['name']?.toString() ?? 'غير محدد',
      collegeId: data['collegeId']?.toString() ?? '',
      // تأكد من مطابقة اسم الحقل في Firestore (HODId أم hodId)
      hodId: (data['HODId'] ?? data['hodId'])?.toString() ?? '',
      // معالجة التاريخ بأمان
      createdAt: _safeParseDate(data['createdAt']),
    );
  }
}
