import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'faculty_member_model.dart'; // استدعاء الموديل

class FacultyMembersViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. جلب البيانات كـ Stream جاهز للاستخدام في الواجهة
  Stream<List<FacultyMemberModel>> getFacultyMembersStream() {
    return _firestore.collection('faculty_members').snapshots().map((snapshot) {
      // تحويل كل Document إلى FacultyMemberModel
      return snapshot.docs.map((doc) => FacultyMemberModel.fromFirestore(doc)).toList();
    });
  }

  // 2. دالة الحذف
  Future<void> deleteFacultyMember(String memberId) async {
    try {
      await _firestore.collection('faculty_members').doc(memberId).delete();
    } catch (e) {
      debugPrint('Error deleting faculty member: $e');
    }
  }
}
