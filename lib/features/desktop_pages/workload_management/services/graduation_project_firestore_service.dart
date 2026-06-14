import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/graduation_project_group.dart';

class GraduationProjectFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'graduation_project_groups';

  Future<List<GraduationProjectGroup>> getGroupsForTeacher(String teacherName) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('teacherName', isEqualTo: teacherName)
        .get();
    
    return snapshot.docs.map((doc) {
      return GraduationProjectGroup.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<List<GraduationProjectGroup>> getAllGroups() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    return snapshot.docs.map((doc) {
      return GraduationProjectGroup.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<void> saveGroup(GraduationProjectGroup group) async {
    if (group.id.isEmpty) {
      await _firestore.collection(_collectionName).add(group.toMap());
    } else {
      await _firestore.collection(_collectionName).doc(group.id).set(group.toMap());
    }
  }

  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection(_collectionName).doc(groupId).delete();
  }

  Future<void> deleteAllGroupsForTeacher(String teacherName) async {
    final snapshot = await _firestore
        .collection(_collectionName)
        .where('teacherName', isEqualTo: teacherName)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<int> getNextGroupNumber(String teacherName) async {
    final groups = await getGroupsForTeacher(teacherName);
    if (groups.isEmpty) return 1;
    return groups.map((g) => g.groupNumber).reduce((a, b) => a > b ? a : b) + 1;
  }
}
