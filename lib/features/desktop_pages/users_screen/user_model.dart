import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String createdAt;
  final String? faculty;
  final String? department;
  final String? level;
  final String? status;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.faculty,
    this.department,
    this.level,
    this.status,
  });

  // دالة مساعدة لتحويل بيانات Firestore إلى Object
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 1. استلام القيمة كـ dynamic أولاً (بدون تحديد نوع)
    final rawDate = data['createAt'] ?? data['createdAt'];

    // 2. التحقق من النوع قبل التحويل
    String createdAtString = '-';
    if (rawDate is Timestamp) {
      createdAtString = rawDate.toDate().toString().split(' ')[0];
    } else if (rawDate is String) {
      createdAtString = rawDate.split(' ')[0];
    }

    return UserModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'غير معروف',
      email: data['email']?.toString() ?? 'غير معروف',
      phone: data['phone']?.toString() ?? 'غير معروف',
      role: data['role']?.toString() ?? 'غير محدد',
      createdAt: createdAtString, // السطر 32 الآن أصبح آمناً
      faculty: data['faculty']?.toString(),
      department: data['department']?.toString(),
      level: data['level']?.toString(),
      status: data['status']?.toString(),
    );
  }
  // دالة مساعدة لتحويل بيانات SQLite إلى Object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    String parsedDate = '-';
    // الانتباه لاسم الحقل الدقيق في جدول SQLite
    if (map['created_at'] != null) {
      DateTime? dt = DateTime.tryParse(map['created_at'].toString());
      if (dt != null) {
        parsedDate =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else {
        parsedDate = map['created_at'].toString();
      }
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'غير معروف',
      email: map['email']?.toString() ?? 'غير معروف',
      phone: map['phone']?.toString() ?? 'غير متوفر',
      role: map['role']?.toString() ?? 'غير محدد',
      createdAt: parsedDate,
      faculty: map['faculty']?.toString(),
      department: map['department']?.toString(),
      level: map['level']?.toString(),
      status: map['status']?.toString(),
    );
  }
}
