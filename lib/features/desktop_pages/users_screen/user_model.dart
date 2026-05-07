import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String createdAt;

  // حقول اختيارية (Nullable) بناءً على تصميم الجدول
  final String? faculty;
  final String? department;
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
    this.status,
  });

  // 🔄 تحويل البيانات القادمة من SQLite إلى كائن
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      createdAt:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),

      // الحقول الاختيارية
      faculty: map['faculty']?.toString(),
      department: map['department']?.toString(),
      status: map['status']?.toString(),
    );
  }

  // 🔄 تحويل الكائن إلى خريطة (Map) لحفظه في SQLite أو Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'created_at': createdAt,
      'faculty': faculty,
      'department': department,
      'status': status,
    };
  }

  // 🔄 دالة إضافية لجلب البيانات من Firebase بشكل آمن
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // معالجة التاريخ إذا كان بصيغة Timestamp من الفايربيس
    String parseDate(dynamic dateField) {
      if (dateField is Timestamp) return dateField.toDate().toIso8601String();
      return dateField?.toString() ?? DateTime.now().toIso8601String();
    }

    return UserModel(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      role: data['role']?.toString() ?? '',
      createdAt: parseDate(data['created_at']),
      faculty: data['faculty']?.toString(),
      department: data['department']?.toString(),
      status: data['status']?.toString(),
    );
  }
}
