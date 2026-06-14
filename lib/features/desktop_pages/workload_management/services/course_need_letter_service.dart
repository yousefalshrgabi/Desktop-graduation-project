import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';

import '../models/semester_nasab_assignment.dart';
import 'computed_nasab_service.dart';
import 'semester_nasab_firestore_service.dart';
import '../utils/app_file_saver.dart';
import '../utils/docx_template_helper.dart';
import '../utils/level_labels.dart';
import '../utils/practical_hours_calculator.dart';

class CourseNeedRow {
  const CourseNeedRow({
    required this.courseName,
    required this.hours,
    required this.department,
    required this.level,
  });

  final String courseName;
  final int hours;
  final String department;
  final int level;

  Map<String, dynamic> toMap() {
    return {
      'courseName': courseName,
      'hours': hours,
      'department': department,
      'level': level,
    };
  }

  factory CourseNeedRow.fromMap(Map<String, dynamic> map) {
    return CourseNeedRow(
      courseName: (map['courseName'] ?? '').toString(),
      hours: (map['hours'] as num?)?.toInt() ?? 0,
      department: (map['department'] ?? '').toString(),
      level: (map['level'] as num?)?.toInt() ?? 0,
    );
  }
}

class CourseNeedLetterData {
  const CourseNeedLetterData({
    required this.theoryRows,
    required this.practicalRows,
  });

  final List<CourseNeedRow> theoryRows;
  final List<CourseNeedRow> practicalRows;

  bool get isEmpty => theoryRows.isEmpty && practicalRows.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'theoryRows': theoryRows.map((row) => row.toMap()).toList(),
      'practicalRows': practicalRows.map((row) => row.toMap()).toList(),
    };
  }

  factory CourseNeedLetterData.fromMap(Map<String, dynamic> map) {
    List<CourseNeedRow> rowsFor(String key) {
      final raw = map[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((row) => CourseNeedRow.fromMap(row.cast<String, dynamic>()))
          .toList();
    }

    return CourseNeedLetterData(
      theoryRows: rowsFor('theoryRows'),
      practicalRows: rowsFor('practicalRows'),
    );
  }
}

class SavedCourseNeedLetter {
  const SavedCourseNeedLetter({
    required this.id,
    required this.collegeName,
    required this.term,
    required this.data,
    this.createdAt,
    this.createdByEmail = '',
  });

  final String id;
  final String collegeName;
  final String term;
  final CourseNeedLetterData data;
  final DateTime? createdAt;
  final String createdByEmail;

  factory SavedCourseNeedLetter.fromFirestore(
    String id,
    Map<String, dynamic> map,
  ) {
    final createdAt = map['createdAt'];
    return SavedCourseNeedLetter(
      id: id,
      collegeName: (map['collegeName'] ?? '').toString(),
      term: (map['term'] ?? '').toString(),
      data: CourseNeedLetterData.fromMap(
        (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      createdByEmail: (map['createdByEmail'] ?? '').toString(),
    );
  }
}

class CourseNeedLetterService {
  CourseNeedLetterService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _templateAsset = 'assets/templates/course_need_letter_template.docx';
  static const collection = 'course_need_letters';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static CourseNeedLetterData buildData({
    required List<SemesterNasabRow> assignmentRows,
    required List<PlanCourseSlot> slots,
    required Map<String, int> groupCounts,
  }) {
    final assignments = <String, SemesterNasabAssignment>{
      for (final row in assignmentRows) row.course.courseKey: row.assignment,
    };
    final theory = <CourseNeedRow>[];
    final practical = <CourseNeedRow>[];

    for (final slot in ComputedNasabService.uniqueCourseSlots(slots)) {
      if (_excludedCourseName(slot.nameAr)) continue;

      final assignment = assignments[slot.courseKey];
      if (assignment == null) continue;

      if (slot.creditTheory > 0 &&
          assignment.theoryTeacherName.trim().isEmpty) {
        theory.add(
          CourseNeedRow(
            courseName: slot.nameAr,
            hours: slot.creditTheory + (slot.practicalPerGroup > 0 ? 1 : 0),
            department: slot.programName,
            level: slot.level,
          ),
        );
      }

      if (slot.practicalPerGroup > 0 &&
          assignment.practicalTeacherName.trim().isEmpty) {
        final groupCount =
            groupCounts[_groupKey(slot.programName, slot.level)] ?? 1;
        practical.add(
          CourseNeedRow(
            courseName: slot.nameAr,
            hours: PracticalHoursCalculator.nasabHoursForCourse(
              practicalHoursPerGroup: slot.practicalPerGroup,
              groupCount: groupCount,
            ),
            department: slot.programName,
            level: slot.level,
          ),
        );
      }
    }

    int compare(CourseNeedRow a, CourseNeedRow b) {
      final dept = a.department.compareTo(b.department);
      if (dept != 0) return dept;
      final level = a.level.compareTo(b.level);
      if (level != 0) return level;
      return a.courseName.compareTo(b.courseName);
    }

    theory.sort(compare);
    practical.sort(compare);
    return CourseNeedLetterData(theoryRows: theory, practicalRows: practical);
  }

  static String _groupKey(String programName, int level) =>
      '${programName.trim()}|$level';

  static bool _excludedCourseName(String name) {
    final normalized = _normalizeArabic(name);
    return normalized.startsWith(_normalizeArabic('مشروع تخرج')) ||
        normalized.startsWith(_normalizeArabic('التدريب الميداني'));
  }

  static String _normalizeArabic(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064b-\u065f]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String> uploadForDean({
    required String collegeName,
    required String term,
    required CourseNeedLetterData data,
  }) async {
    final user = _auth.currentUser;
    final doc = await _db.collection(collection).add({
      'collegeName': collegeName.trim(),
      'term': term,
      'data': data.toMap(),
      'createdByUid': user?.uid ?? '',
      'createdByEmail': user?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'submitted',
    });
    return doc.id;
  }

  Future<List<SavedCourseNeedLetter>> listForCollege({
    required String collegeName,
    bool forceRefresh = false,
  }) async {
    final query = _db
        .collection(collection)
        .where('collegeName', isEqualTo: collegeName.trim());
    final snap =
        await query.get(const GetOptions(source: Source.serverAndCache));
    final list = snap.docs
        .map((doc) => SavedCourseNeedLetter.fromFirestore(doc.id, doc.data()))
        .toList();
    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  Future<void> exportLetter({
    required String collegeName,
    required String term,
    required CourseNeedLetterData data,
    DateTime? now,
  }) async {
    final loaded = await DocxTemplateHelper.loadTemplate(_templateAsset);
    var documentXml = loaded.documentXml;
    final headerXml =
        DocxTemplateHelper.readXmlFile(loaded.archive, 'word/header1.xml');

    final tables = DocxTemplateHelper.extractTopLevelTables(documentXml);
    if (tables.length < 2) {
      throw Exception(
          'قالب خطاب مقررات الاحتياج لا يحتوي على الجدولين المتوقعين.');
    }

    final theoryTable = _fillTable(tables[0].xml, data.theoryRows);
    final practicalTable = _fillTable(tables[1].xml, data.practicalRows);
    documentXml = documentXml.replaceRange(
      tables[1].start,
      tables[1].end,
      practicalTable,
    );
    documentXml = documentXml.replaceRange(
      tables[0].start,
      tables[0].end,
      theoryTable,
    );

    final deanName = await _loadDeanName(collegeName);
    if (deanName.isNotEmpty) {
      documentXml = DocxTemplateHelper.replaceParagraphsWhere(
        documentXml,
        (text) => text.contains('عميد الكلية'),
        (_) => 'عميد الكلية\n$deanName',
      );
    }

    final current = now ?? DateTime.now();
    final replacements = <String, List<int>>{
      'word/document.xml': utf8.encode(documentXml),
    };
    if (headerXml != null) {
      replacements['word/header1.xml'] = utf8.encode(
        _fillHeader(headerXml, current),
      );
    }

    final outBytes = DocxTemplateHelper.repackDocxFiles(
      loaded.archive,
      replacements,
    );
    final safeCollege = collegeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final termName = term == 'first' ? 'الفصل_الأول' : 'الفصل_الثاني';
    await AppFileSaver.saveExportedFile(
      name: 'خطاب_مقررات_الاحتياج_${safeCollege}_$termName',
      bytes: Uint8List.fromList(outBytes),
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  String _fillTable(String tableXml, List<CourseNeedRow> dataRows) {
    final rows = DocxTemplateHelper.splitRows(tableXml);
    if (rows.length < 2) return tableXml;

    final header = rows.first;
    final sample = rows.length > 2 ? rows[1] : rows.first;
    final total = rows.last;
    final filledRows = <String>[header];

    for (final row in dataRows) {
      var rowXml = sample;
      rowXml = DocxTemplateHelper.setCellText(rowXml, 0, row.courseName);
      rowXml = DocxTemplateHelper.setCellText(rowXml, 1, row.hours.toString());
      rowXml = DocxTemplateHelper.setCellText(rowXml, 2, row.department);
      rowXml = DocxTemplateHelper.setCellText(
        rowXml,
        3,
        LevelLabels.forLevel(row.level),
      );
      filledRows.add(rowXml);
    }

    var totalXml = total;
    final totalHours = dataRows.fold<int>(0, (total, row) => total + row.hours);
    totalXml = DocxTemplateHelper.setCellText(totalXml, 0, 'الإجمالي');
    totalXml = DocxTemplateHelper.setCellText(
      totalXml,
      1,
      totalHours == 0 ? '' : '$totalHours ساعة',
    );
    totalXml = DocxTemplateHelper.setCellText(totalXml, 2, '');
    totalXml = DocxTemplateHelper.setCellText(totalXml, 3, '');
    filledRows.add(totalXml);

    return DocxTemplateHelper.replaceTableRows(tableXml, filledRows);
  }

  String _fillHeader(String headerXml, DateTime now) {
    final arDate = '${now.day.toString().padLeft(2, '0')} / '
        '${now.month.toString().padLeft(2, '0')} / ${now.year}';
    final enDate = '${now.year} / '
        '${now.month.toString().padLeft(2, '0')} / '
        '${now.day.toString().padLeft(2, '0')}';

    return DocxTemplateHelper.replaceParagraphsWhere(
      headerXml,
      (text) => text.contains('التاريخ:') || text.contains('Date:'),
      (text) {
        if (text.contains('التاريخ:')) {
          return 'التاريخ: $arDate';
        }
        return 'Date: $enDate';
      },
    );
  }

  Future<String> _loadDeanName(String collegeName) async {
    String normalizeDocId(String name) {
      return name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[\u064b-\u065f]'), '')
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
    }

    final docId = normalizeDocId(collegeName);
    final doc = await _db.collection('colleges').doc(docId).get();
    final data = doc.data();
    if (data == null) return '';

    final savedName = (data['dean_name'] ?? '').toString().trim();
    if (savedName.isNotEmpty) return savedName;

    final deanId = (data['dean_id'] ?? '').toString().trim();
    if (deanId.isEmpty) return '';

    final facultyDoc =
        await _db.collection('faculty_members').doc(deanId).get();
    final faculty = facultyDoc.data();
    final personal =
        (faculty?['personal_info'] as Map?)?.cast<String, dynamic>() ?? {};
    return (personal['name'] ?? '').toString().trim();
  }
}
