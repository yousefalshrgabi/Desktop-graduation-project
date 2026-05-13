import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String id;
  final String arName;
  final String enName;

  SubjectModel({
    required this.id,
    required this.arName,
    required this.enName,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SubjectModel(
      id: doc.id,
      arName: data['ar_name']?.toString() ?? 'غير محدد',
      enName: data['en_name']?.toString() ?? 'Undefined',
    );
  }
}
