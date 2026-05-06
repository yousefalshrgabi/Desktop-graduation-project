import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeModel {
  final String id;
  final String arName;
  final String enName;
  final String code;
  final String deanId;
  final String academicViceDeanId;
  final String studentViceDeanId;
  final String createdAt;

  CollegeModel({
    required this.id,
    required this.arName,
    required this.enName,
    required this.code,
    required this.deanId,
    required this.academicViceDeanId,
    required this.studentViceDeanId,
    required this.createdAt,
  });

  // دالة مساعدة ذكية لتحويل أي قيمة قادمة من Firestore إلى نص تاريخ
  static String _parseDate(dynamic value) {
    if (value == null) return '-';

    // حالة 1: إذا كان نوع البيانات Timestamp (الوضع الطبيعي لـ Firestore)
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    // حالة 2: إذا كان نوع البيانات String (تاريخ نصي مخزن مسبقاً)
    if (value is String) {
      // إذا كان النص يحتوي على تاريخ صالح، نقوم بتنسيقه، وإلا نعيده كما هو
      DateTime? dt = DateTime.tryParse(value);
      if (dt != null) {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
      return value; // أعد النص كما هو إذا لم نستطع تحويله
    }

    return '-';
  }

  // دالة تحويل بيانات SQLite إلى Object
  factory CollegeModel.fromMap(Map<String, dynamic> map) {
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

    return CollegeModel(
      id: map['id']?.toString() ?? '',
      // استخدام أسماء الأعمدة المطابقة لجدول SQLite تماماً
      arName: map['ar_name']?.toString() ?? 'غير محدد',
      enName: map['en_name']?.toString() ?? 'غير محدد',
      code: map['code']?.toString() ?? 'غير محدد',
      deanId: map['dean_id']?.toString() ?? '',
      academicViceDeanId: map['academic_vice_dean_id']?.toString() ?? '',
      studentViceDeanId: map['student_vice_dean_id']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  factory CollegeModel.fromFirestore(DocumentSnapshot doc) {
    // التأكد من أن البيانات موجودة وليست Null
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CollegeModel(
      id: doc.id,
      // استخدام toString() مباشرة بدلاً من التحويل القسري (Casting)
      arName: data['ar_name']?.toString() ?? 'غير محدد',
      enName: data['en_name']?.toString() ?? 'غير محدد',
      code: data['code']?.toString() ?? 'غير محدد',
      deanId: data['deanId']?.toString() ?? '',
      academicViceDeanId: data['academicViceDeanId']?.toString() ?? '',
      studentViceDeanId: data['studentViceDeanId']?.toString() ?? '',
      // استخدام الدالة الذكية لمعالجة التاريخ لتجنب الـ Crash
      createdAt: _parseDate(data['createdAt']),
    );
  }
}
