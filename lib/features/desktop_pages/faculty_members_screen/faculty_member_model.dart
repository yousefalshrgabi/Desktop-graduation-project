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

  // دالة مساعدة لتحويل بيانات Firestore إلى Object
  factory FacultyMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAtString = createdAtTimestamp != null
        ? createdAtTimestamp.toDate().toString().split(' ')[0]
        : '-';

    return FacultyMemberModel(
      id: doc.id,
      name: data['name'] ?? 'غير معروف',
      email: data['email'] ?? 'غير متوفر',
      department: data['department'] ?? 'غير محدد',
      academicDegree: data['academicDegree'] ?? 'غير محدد',
      status: data['status'] ?? 'نشط',
      createdAt: createdAtString,
    );
  }
}
