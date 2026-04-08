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
    final data = doc.data() as Map<String, dynamic>;

    final createdAtTimestamp = data['createAt'] as Timestamp?;
    final createdAtString = createdAtTimestamp != null
        ? createdAtTimestamp.toDate().toString().split(' ')[0]
        : '-';

    return UserModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'غير معروف',
      email: data['email']?.toString() ?? 'غير معروف',
      phone: data['phone']?.toString() ?? 'غير معروف',
      role: data['role']?.toString() ?? 'غير محدد',
      createdAt: createdAtString,
      faculty: data['faculty']?.toString(),
      department: data['department']?.toString(),
      level: data['level']?.toString(),
      status: data['status']?.toString(),
    );
  }
}
