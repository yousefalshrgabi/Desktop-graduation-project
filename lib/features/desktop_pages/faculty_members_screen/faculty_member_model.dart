import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyMemberModel {
  final String id;
  final String name;
  final String email;
  final String department;
  final String academicDegree;
  final String status;
  final String createdAt;

  FacultyMemberModel({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.academicDegree,
    required this.status,
    required this.createdAt,
  });

  /// دالة معالجة التاريخ المرنة لمنع الانهيار
  static String _parseDate(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      // تنسيق التاريخ بصيغة YYYY-MM-DD
      final dt = value.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    if (value is String) {
      // إذا كان مخزناً كنص أصلاً، نحاول تنظيفه أو أخذه كما هو
      return value.split(' ')[0];
    }

    return '-';
  }

  // دالة تحويل بيانات SQLite إلى Object
  factory FacultyMemberModel.fromMap(Map<String, dynamic> map) {
    String parsedDate = '-';
    // الانتباه لاسم الحقل في SQLite
    if (map['created_at'] != null) {
      DateTime? dt = DateTime.tryParse(map['created_at'].toString());
      if (dt != null) {
        parsedDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else {
        parsedDate = map['created_at'].toString();
      }
    }

    return FacultyMemberModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'غير معروف',
      email: map['email']?.toString() ?? 'غير متوفر',
      department: map['department']?.toString() ?? 'غير محدد',
      academicDegree: map['academic_degree']?.toString() ??
          'غير محدد', // الانتباه لاسم العمود
      status: map['status']?.toString() ?? 'نشط',
      createdAt: parsedDate,
    );
  }

  factory FacultyMemberModel.fromFirestore(DocumentSnapshot doc) {
    // استخدام Safe Casting للبيانات
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return FacultyMemberModel(
      id: doc.id,
      // استخدام toString() مع القيم النصية لضمان عدم حدوث Null Check Error
      name: data['name']?.toString() ?? 'غير معروف',
      email: data['email']?.toString() ?? 'غير متوفر',
      department: data['department']?.toString() ?? 'غير محدد',
      academicDegree: data['academicDegree']?.toString() ?? 'غير محدد',
      status: data['status']?.toString() ?? 'نشط',
      // استدعاء الدالة الآمنة للتعامل مع التاريخ
      createdAt: _parseDate(data['createdAt']),
    );
  }
}
