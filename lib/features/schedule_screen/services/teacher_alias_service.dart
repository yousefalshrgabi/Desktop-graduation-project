import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_alias.dart';

class TeacherAliasService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionName = 'teacher_aliases';

  /// Fetch all aliases for a specific college
  Future<List<TeacherAlias>> getAliasesForCollege(String collegeName) async {
    final snap = await _db
        .collection(_collectionName)
        .where('college_name', isEqualTo: collegeName)
        .get();

    return snap.docs.map((doc) {
      return TeacherAlias.fromMap(doc.id, doc.data());
    }).toList();
  }

  /// Check if a specific alias string is mapped to a canonical name
  Future<TeacherAlias?> getAliasByName(
      String collegeName, String aliasName) async {
    final snap = await _db
        .collection(_collectionName)
        .where('college_name', isEqualTo: collegeName)
        .where('alias_name', isEqualTo: aliasName)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return TeacherAlias.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Save or update an alias
  Future<void> saveAlias(TeacherAlias alias) async {
    if (alias.id.isEmpty) {
      // Avoid exact duplicates
      final existing = await getAliasByName(alias.collegeName, alias.aliasName);
      if (existing != null) {
        // Update existing instead of creating a duplicate
        await _db.collection(_collectionName).doc(existing.id).update({
          'canonical_name': alias.canonicalName,
        });
        return;
      }
      await _db.collection(_collectionName).add(alias.toMap());
    } else {
      await _db.collection(_collectionName).doc(alias.id).set(alias.toMap());
    }
  }

  /// Delete an alias
  Future<void> deleteAlias(String aliasId) async {
    await _db.collection(_collectionName).doc(aliasId).delete();
  }
}
