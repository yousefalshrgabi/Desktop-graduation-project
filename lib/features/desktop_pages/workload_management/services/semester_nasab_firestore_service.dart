import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/models/aggregated_plan_course.dart';
import '../models/semester_nasab_assignment.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/utils/course_coverage.dart';
import 'package:academic_affairs_management/features/schedule_screen/services/firestore_cache_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/study_plans_ui/services/study_plan_firestore_service.dart';

/// Vice-dean assignments for ورقة1-style nasab (theory / practical per course).
class SemesterNasabFirestoreService {
  SemesterNasabFirestoreService({
    FirebaseFirestore? firestore,
    StudyPlanFirestoreService? studyPlans,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _studyPlans = studyPlans ?? StudyPlanFirestoreService();

  final FirebaseFirestore _db;
  final StudyPlanFirestoreService _studyPlans;

  static const String collection = 'semester_nasab_assignments';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(collection);

  Future<List<SemesterNasabRow>> loadSheet({
    required String collegeName,
    required String term,
    bool forceRefresh = false,
  }) async {
    final courses = await _studyPlans.collectCoursesForTerm(
      collegeName: collegeName,
      term: term,
      forceRefresh: forceRefresh,
    );

    final assignmentSnap = await FirestoreCacheService.queryCachedFirst(
      _col
          .where('collegeName', isEqualTo: collegeName.trim())
          .where('term', isEqualTo: term),
      forceRefresh: forceRefresh,
    );

    final byKey = <String, SemesterNasabAssignment>{};
    for (final doc in assignmentSnap.docs) {
      final a = SemesterNasabAssignment.fromMap(doc.id, doc.data());
      byKey[a.courseKey] = a;
    }

    return courses.map((c) {
      final saved = byKey[c.courseKey];
      return SemesterNasabRow(
        course: c,
        assignment: saved ??
            SemesterNasabAssignment(
              collegeName: collegeName,
              term: term,
              courseKey: c.courseKey,
              courseNameAr: c.nameAr,
              codeLocal: c.codeLocal,
              coverageScope: c.coverageScope.firestoreValue,
            ),
      );
    }).toList();
  }

  Future<void> saveAll({
    required String collegeName,
    required String term,
    required List<SemesterNasabRow> rows,
  }) async {
    WriteBatch batch = _db.batch();
    var count = 0;

    Future<void> flush() async {
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }

    for (final row in rows) {
      final a = row.assignment;
      final docId = SemesterNasabAssignment.docIdFor(
        collegeName: collegeName,
        term: term,
        courseKey: row.course.courseKey,
      );
      batch.set(_col.doc(docId), {
        ...a.toMap(),
        'collegeName': collegeName,
        'term': term,
        'courseKey': row.course.courseKey,
        'courseNameAr': row.course.nameAr,
        'codeLocal': row.course.codeLocal,
        'coverageScope': row.course.coverageScope.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
      await flush();
    }

    if (count > 0) {
      await batch.commit();
    }
  }
}

class SemesterNasabRow {
  SemesterNasabRow({
    required this.course,
    required this.assignment,
  });

  final AggregatedPlanCourse course;
  final SemesterNasabAssignment assignment;

  CourseCoverageScope get coverageScope => course.coverageScope;
}
