import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/faculty_option.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/firestore_cache_service.dart';

class FacultyFirestoreService {
  FacultyFirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  final Map<String, List<FacultyOption>> _collegeCache = {};
  List<FacultyOption>? _allCache;

  Future<List<FacultyOption>> listByCollege(
    String collegeName, {
    bool forceRefresh = false,
  }) async {
    final college = collegeName.trim();
    if (!forceRefresh && _collegeCache.containsKey(college)) {
      return _collegeCache[college]!;
    }

    try {
      // 1. إيجاد الكلية
      final collegeSnap = await FirestoreCacheService.queryCachedFirst(
        _db.collection('colleges'),
        forceRefresh: forceRefresh,
      );

      String? collegeId;
      for (var doc in collegeSnap.docs) {
        if ((doc.data()['ar_name']?.toString() ?? '').trim() == college) {
          collegeId = doc.id;
          break;
        }
      }

      if (collegeId == null) {
        _collegeCache[college] = [];
        return [];
      }

      // 2. إيجاد جميع الأقسام التابعة لهذه الكلية
      final deptSnap = await FirestoreCacheService.queryCachedFirst(
        _db.collection('departments'),
        forceRefresh: forceRefresh,
      );

      final validDepts = <String>{};
      for (var d in deptSnap.docs) {
        if ((d.data()['college_id']?.toString() ?? '') == collegeId) {
          validDepts.add(d.id.trim());
          validDepts.add((d.data()['name']?.toString() ?? '').trim());
        }
      }

      // 3. جلب جميع المعلمين وفلترتهم بناءً على قسمهم
      final all = await listUniversityWide(forceRefresh: forceRefresh);
      
      final list = all.where((f) {
        final fCollege = f.college.trim();
        if (fCollege == college) return true;
        
        final fDept = f.department.trim();
        return fDept.isNotEmpty && validDepts.contains(fDept);
      }).toList();

      _collegeCache[college] = list;
      return list;
    } catch (e) {
      // في حالة حدوث خطأ في الفهرسة أو الاستعلام، نرجع قائمة فارغة مؤقتاً
      return [];
    }
  }

  Future<List<FacultyOption>> listUniversityWide({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _allCache != null) return _allCache!;

    final snap = await FirestoreCacheService.queryCachedFirst(
      _db.collection('faculty_members'),
      forceRefresh: forceRefresh,
    );

    final list = _mapFaculty(snap.docs);
    _allCache = list;
    return list;
  }

  List<FacultyOption> _mapFaculty(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final list = docs
        .map((d) => FacultyOption.fromFirestore(d.id, d.data()))
        .where((f) => f.name.isNotEmpty)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void clearMemoryCache() {
    _collegeCache.clear();
    _allCache = null;
  }
}
