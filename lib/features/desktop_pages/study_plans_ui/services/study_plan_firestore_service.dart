import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/aggregated_plan_course.dart';
import '../models/study_plan.dart';
import '../utils/course_coverage.dart';
import '../../../schedule_screen/services/firestore_cache_service.dart';

/// Persists parsed study plans to Firestore for use across the app.
class StudyPlanFirestoreService {
  StudyPlanFirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String plansCollection = 'study_plans';
  static const String coursesSubcollection = 'courses';
  static const String catalogsCollection = 'study_plan_course_catalogs';

  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection(plansCollection);

  CollectionReference<Map<String, dynamic>> get _catalogs =>
      _db.collection(catalogsCollection);

  /// Saves a complete plan while storing shared course data once per program.
  Future<void> savePlan(StudyPlan plan) async {
    if ((plan.trackName ?? '').trim().isNotEmpty) {
      await _deleteLegacyCommonPlan(plan);
    }
    final planRef = _plans.doc(plan.documentId);
    final catalogId = _catalogIdFor(plan.collegeName, plan.programName);
    final catalogRef = _catalogs.doc(catalogId);
    // Reads hit the server so a second track can reuse common catalog courses.
    final existingPlan =
        await planRef.get(const GetOptions(source: Source.server));
    final existingCourses = await planRef
        .collection(coursesSubcollection)
        .get(const GetOptions(source: Source.server));
    final existingCatalog = await catalogRef
        .collection(coursesSubcollection)
        .get(const GetOptions(source: Source.server));
    final existingCatalogIds =
        existingCatalog.docs.map((doc) => doc.id).toSet();

    WriteBatch batch = _db.batch();
    var batchCount = 0;

    Future<void> flush() async {
      if (batchCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    for (final doc in existingCourses.docs) {
      batch.delete(doc.reference);
      batchCount++;
      await flush();
    }

    batch.set(
        planRef,
        {
          ...plan.toSummaryMap(),
          'courseCatalogId': catalogId,
          'lastUploadAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batchCount++;
    await flush();

    final courseMaps = plan.coursesToFirestoreMaps();
    for (var i = 0; i < courseMaps.length; i++) {
      final data = courseMaps[i];
      final course = StudyPlanCourse.fromMap(data);
      final courseId = _courseCatalogDocId(course);
      final membership = Map<String, dynamic>.from(data);
      final courseData = Map<String, dynamic>.from(course.toMap())
        ..remove('sequence');
      for (final key in courseData.keys) {
        membership.remove(key);
      }
      membership['sequence'] = course.sequence;
      membership['courseCatalogId'] = courseId;
      membership['catalogId'] = catalogId;

      final level = (membership['level'] as num?)?.toInt();
      final splitSemester = plan.trackStartSemester;
      final semesterNumber = level == null
          ? null
          : ((level - 1) * 2) +
              ((membership['term'] ?? '').toString() == 'second' ? 2 : 1);
      final isExistingSharedCourse = !existingPlan.exists &&
          splitSemester != null &&
          semesterNumber != null &&
          semesterNumber < splitSemester &&
          existingCatalogIds.contains(courseId);
      if (!isExistingSharedCourse) {
        batch.set(
          catalogRef.collection(coursesSubcollection).doc(courseId),
          {
            ...courseData,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        batchCount++;
        await flush();
      }

      final refId = _membershipDocId(membership, courseId, i);
      batch.set(planRef.collection(coursesSubcollection).doc(refId), {
        ...membership,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      batchCount++;
      await flush();
    }

    if (batchCount > 0) {
      await batch.commit();
    }
  }

  Future<void> _deleteLegacyCommonPlan(StudyPlan trackPlan) async {
    final commonId = StudyPlan(
      collegeName: trackPlan.collegeName,
      programName: trackPlan.programName,
      semesters: const [],
    ).documentId;
    if (commonId == trackPlan.documentId) return;

    final common = await _plans
        .doc(commonId)
        .get(const GetOptions(source: Source.serverAndCache));
    if (!common.exists) return;

    final data = common.data();
    final commonTrack = (data?['trackName'] ?? '').toString().trim();
    if (commonTrack.isEmpty) await deletePlan(commonId);
  }

  /// Lists plan summaries — cache first to avoid billed reads on repeat visits.
  Future<List<StudyPlanSummary>> listPlans({
    String? collegeFilter,
    bool forceRefresh = false,
  }) async {
    Query<Map<String, dynamic>> query = _plans.orderBy('collegeName');
    if (collegeFilter != null && collegeFilter.trim().isNotEmpty) {
      query = query.where('collegeName', isEqualTo: collegeFilter.trim());
    }

    final snap = await FirestoreCacheService.queryCachedFirst(
      query,
      forceRefresh: forceRefresh,
    );

    return snap.docs
        .map((d) => StudyPlanSummary.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<StudyPlanSummary?> getPlanSummary(
    String planId, {
    bool forceRefresh = false,
  }) async {
    final doc = await FirestoreCacheService.docCachedFirst(
      _plans.doc(planId),
      forceRefresh: forceRefresh,
    );
    if (!doc.exists || doc.data() == null) return null;
    return StudyPlanSummary.fromFirestore(doc.id, doc.data()!);
  }

  Future<List<Map<String, dynamic>>> getPlanCoursesRaw(
    String planId, {
    bool forceRefresh = false,
  }) async {
    final snap = await FirestoreCacheService.collectionCachedFirst(
      _plans.doc(planId).collection(coursesSubcollection),
      forceRefresh: forceRefresh,
    );
    final rows = <Map<String, dynamic>>[];
    final catalogRows = <String, Map<String, Map<String, dynamic>>>{};
    for (final doc in snap.docs) {
      final membership = doc.data();
      final courseCatalogId =
          (membership['courseCatalogId'] ?? '').toString().trim();
      final catalogId = (membership['catalogId'] ?? '').toString().trim();
      if (courseCatalogId.isEmpty || catalogId.isEmpty) {
        rows.add({...membership, '_docId': doc.id});
        continue;
      }

      final catalog = catalogRows.putIfAbsent(
        catalogId,
        () => <String, Map<String, dynamic>>{},
      );
      if (catalog.isEmpty) {
        final catalogSnap = await FirestoreCacheService.collectionCachedFirst(
          _catalogs.doc(catalogId).collection(coursesSubcollection),
          forceRefresh: forceRefresh,
        );
        for (final courseDoc in catalogSnap.docs) {
          catalog[courseDoc.id] = courseDoc.data();
        }
      }
      rows.add({
        ...?catalog[courseCatalogId],
        ...membership,
        '_docId': doc.id,
      });
    }
    rows.sort((a, b) {
      final sk = (a['semesterKey'] ?? '')
          .toString()
          .compareTo((b['semesterKey'] ?? '').toString());
      if (sk != 0) return sk;
      return ((a['sequence'] as num?) ?? 0)
          .compareTo((b['sequence'] as num?) ?? 0);
    });
    return rows;
  }

  Future<List<StudyPlanCourse>> getPlanCourses(
    String planId, {
    bool forceRefresh = false,
  }) async {
    final rows = await getPlanCoursesRaw(planId, forceRefresh: forceRefresh);
    return rows.map(StudyPlanCourse.fromMap).toList();
  }

  Future<void> updateCourseCoverage({
    required String planId,
    required String courseDocId,
    required CourseCoverageScope scope,
  }) async {
    final membershipRef =
        _plans.doc(planId).collection(coursesSubcollection).doc(courseDocId);
    final membership = await membershipRef.get(
      const GetOptions(source: Source.serverAndCache),
    );
    final data = membership.data();
    final catalogId = (data?['catalogId'] ?? '').toString().trim();
    final catalogCourseId = (data?['courseCatalogId'] ?? '').toString().trim();
    final target = catalogId.isNotEmpty && catalogCourseId.isNotEmpty
        ? _catalogs
            .doc(catalogId)
            .collection(coursesSubcollection)
            .doc(catalogCourseId)
        : membershipRef;
    await target.set({
      'coverageScope': scope.firestoreValue,
      'coverageUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _catalogIdFor(String collegeName, String programName) {
    return '${_normalizeIdPart(collegeName)}__${_normalizeIdPart(programName)}';
  }

  static String _courseCatalogDocId(StudyPlanCourse course) {
    final key = AggregatedPlanCourse.keyFor(course);
    final normalized = _normalizeIdPart(key);
    return normalized.length > 180 ? normalized.substring(0, 180) : normalized;
  }

  static String _membershipDocId(
    Map<String, dynamic> membership,
    String courseId,
    int index,
  ) {
    final raw =
        '${membership['semesterKey']}_${membership['sequence']}_${courseId}_$index';
    final normalized = _normalizeIdPart(raw);
    return normalized.length > 220 ? normalized.substring(0, 220) : normalized;
  }

  static String _normalizeIdPart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[/\\[\]*\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Unique courses across all college plans for one academic term (first/second).
  Future<List<AggregatedPlanCourse>> collectCoursesForTerm({
    required String collegeName,
    required String term,
    bool forceRefresh = false,
  }) async {
    final plans = await listPlans(
      collegeFilter: collegeName,
      forceRefresh: forceRefresh,
    );
    final byKey = <String, AggregatedPlanCourse>{};

    for (final plan in plans) {
      final rows = await getPlanCoursesRaw(plan.id, forceRefresh: forceRefresh);
      for (final row in rows) {
        if (row['isElectivePool'] == true) continue;
        final rowTerm = (row['term'] ?? '').toString();
        if (rowTerm != term) continue;

        final course = StudyPlanCourse.fromMap(row);
        if (course.nameAr.trim().isEmpty) continue;

        final key = AggregatedPlanCourse.keyFor(course);
        final existing = byKey[key];
        if (existing != null) {
          if (existing.creditPractical == 0 && course.creditPractical != null) {
            byKey[key] = existing.copyWith(
              creditPractical: course.creditPractical,
              creditTheory: course.creditTheory,
            );
          }
          continue;
        }

        byKey[key] = AggregatedPlanCourse(
          courseKey: key,
          nameAr: course.nameAr,
          codeLocal: course.codeLocal,
          codeEn: course.codeEn,
          coverageScope: course.coverageScope,
          creditTheory: course.creditTheory ?? 0,
          creditPractical: course.creditPractical ?? 0,
          sourcePrograms: [plan.displayTitle],
        );
      }
    }

    final list = byKey.values.toList()
      ..sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return list;
  }

  /// Deletes a plan document and all course sub-documents (batched).
  Future<void> deletePlan(String planId) async {
    final planRef = _plans.doc(planId);
    final courses = await planRef
        .collection(coursesSubcollection)
        .get(const GetOptions(source: Source.server));

    WriteBatch batch = _db.batch();
    var batchCount = 0;

    Future<void> flush() async {
      if (batchCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        batchCount = 0;
      }
    }

    for (final doc in courses.docs) {
      batch.delete(doc.reference);
      batchCount++;
      await flush();
    }

    batch.delete(planRef);
    batchCount++;
    await flush();

    if (batchCount > 0) {
      await batch.commit();
    }
  }

  /// Lookup course by code — uses cache-first per plan (still O(plans) queries).
  Future<List<Map<String, dynamic>>> findCoursesByCode({
    required String collegeName,
    required String codeQuery,
    bool forceRefresh = false,
  }) async {
    final q = codeQuery.trim().toLowerCase();
    if (q.isEmpty) return [];

    final plans = await listPlans(
      collegeFilter: collegeName,
      forceRefresh: forceRefresh,
    );
    final results = <Map<String, dynamic>>[];

    for (final plan in plans) {
      final courses = await getPlanCoursesRaw(
        plan.id,
        forceRefresh: forceRefresh,
      );
      for (final row in courses) {
        final c = StudyPlanCourse.fromMap(row);
        final local = c.codeLocal.toLowerCase();
        final en = (c.codeEn ?? '').toLowerCase();
        if (local.contains(q) || en.contains(q)) {
          results.add({
            'planId': plan.id,
            'planTitle': plan.displayTitle,
            'course': c,
          });
        }
      }
    }
    return results;
  }
}
