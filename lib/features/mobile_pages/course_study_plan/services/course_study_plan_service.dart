import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';

import '../../../desktop_pages/workload_management/utils/app_file_saver.dart';
import '../utils/docx_template_helper.dart';
import '../models/course_study_plan_model.dart';

class CourseStudyPlanService {
  CourseStudyPlanService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const settingsCollection = 'course_study_plan_template_settings';
  static const submissionsCollection = 'course_study_plan_submissions';
  static const templateAsset =
      'assets/templates/course_study_plan_template.docx';

  Future<CourseStudyPlanTemplateSettings> loadSettings(String term) async {
    final doc = await _db.collection(settingsCollection).doc(term).get();
    if (!doc.exists || doc.data() == null) {
      return CourseStudyPlanTemplateSettings(
        term: term,
        academicYear: '',
        weekRanges: List<String>.filled(14, ''),
      );
    }
    final data = doc.data()!;
    return CourseStudyPlanTemplateSettings.fromMap(data);
  }

  Future<void> saveSettings(CourseStudyPlanTemplateSettings settings) {
    return _db
        .collection(settingsCollection)
        .doc(settings.term)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  Future<CourseStudyPlanSubmission?> loadSubmission({
    required String facultyDocId,
    required String courseId,
  }) async {
    final docId = _submissionId(facultyDocId, courseId);
    final doc = await _db.collection(submissionsCollection).doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CourseStudyPlanSubmission.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> saveSubmission(CourseStudyPlanSubmission submission) {
    return _db
        .collection(submissionsCollection)
        .doc(submission.id)
        .set(submission.toMap(), SetOptions(merge: true));
  }

  Future<void> updateSubmissionStatus(String id, String newStatus, {String? rejectionReason}) {
    final Map<String, dynamic> data = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (rejectionReason != null) {
      data['rejectionReason'] = rejectionReason;
    } else if (newStatus != 'rejected') {
      // Clear rejection reason if not rejected anymore
      data['rejectionReason'] = FieldValue.delete();
    }
    return _db.collection(submissionsCollection).doc(id).update(data);
  }

  Stream<List<CourseStudyPlanSubmission>> watchSubmissions({
    String? collegeName,
    String? departmentName,
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(submissionsCollection);
    if (collegeName != null && collegeName.trim().isNotEmpty) {
      query = query.where('collegeName', isEqualTo: collegeName.trim());
    }
    if (departmentName != null && departmentName.trim().isNotEmpty) {
      query = query.where('departmentName', isEqualTo: departmentName.trim());
    }
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => CourseStudyPlanSubmission.fromFirestore(
                doc.id,
                doc.data(),
              ))
          .toList();
      list.sort((a, b) {
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  Future<void> exportTemplateSettingsDocx(
    CourseStudyPlanTemplateSettings settings, {
    required String collegeName,
  }) async {
    final bytes = await buildDocx(
      collegeName: collegeName,
      lecturerName: '',
      departmentName: '',
      levelLabel: '',
      courseName: '',
      creditHoursText: '',
      term: settings.term,
      academicYear: settings.academicYear,
      weekRanges: settings.weekRanges,
      entries: List<CourseStudyPlanEntry>.filled(
        settings.weekRanges.length,
        const CourseStudyPlanEntry(
          topicDetails: '',
          theoryHours: '',
          practicalOrDiscussionHours: '',
          notes: '',
        ),
      ),
    );
    await AppFileSaver.saveExportedFile(
      name:
          'كليشة_الخطة_الدراسية_${settings.term == 'first' ? 'الفصل_الأول' : 'الفصل_الثاني'}',
      bytes: Uint8List.fromList(bytes),
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  Future<void> exportSubmissionDocx(
      CourseStudyPlanSubmission submission) async {
    final bytes = await buildDocx(
      collegeName: submission.collegeName,
      lecturerName: submission.facultyName,
      departmentName: submission.departmentName,
      levelLabel: submission.levelLabel,
      courseName: submission.courseName,
      creditHoursText: submission.creditHoursText,
      term: submission.term,
      academicYear: submission.academicYear,
      weekRanges: submission.weekRanges,
      entries: submission.entries,
    );
    final safeName =
        submission.courseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await AppFileSaver.saveExportedFile(
      name: 'الخطة_الدراسية_$safeName',
      bytes: Uint8List.fromList(bytes),
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  Future<void> exportProgressSummaryTable(
    List<CourseStudyPlanSubmission> submissions,
  ) async {
    final rows = <List<dynamic>>[
      <String>[
        'المقرر',
        'مجموعة الطلاب',
        'المدرس',
        'المواضيع المكتملة',
        'إجمالي المواضيع',
        'نسبة الإنجاز',
      ],
      ...submissions.map(
        (submission) => <dynamic>[
          submission.courseName,
          _studentGroupLabel(submission),
          submission.facultyName,
          submission.completedTopics,
          submission.totalTopics,
          '${submission.completionPercent}%',
        ],
      ),
    ];
    final csvString = Csv().encode(rows);
    final bytes = utf8.encode('\uFEFF$csvString');
    await AppFileSaver.saveExportedFile(
      name: 'تقرير_نسب_إنجاز_المقررات',
      bytes: Uint8List.fromList(bytes),
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  }

  Future<List<int>> buildDocx({
    required String collegeName,
    required String lecturerName,
    required String departmentName,
    required String levelLabel,
    required String courseName,
    required String creditHoursText,
    required String term,
    required String academicYear,
    required List<String> weekRanges,
    required List<CourseStudyPlanEntry> entries,
  }) async {
    final loaded = await DocxTemplateHelper.loadTemplate(templateAsset);
    var documentXml = loaded.documentXml;

    final collegeTitle =
        collegeName.trim().isEmpty ? 'كلية' : 'كلية $collegeName';
    documentXml = DocxTemplateHelper.replaceParagraphsWhere(
      documentXml,
      (text) => text.contains('اسم الكلية'),
      (_) => collegeTitle,
    );
    documentXml = DocxTemplateHelper.replaceParagraphsWhere(
      documentXml,
      (text) =>
          text.contains('الخطة الدراسية للفصل الدراسي') &&
          text.contains('العام الجامعي'),
      (_) =>
          'الخطة الدراسية للفصل الدراسي: ${_termLabel(term)}    العام الجامعي : $academicYear م',
    );
    documentXml = DocxTemplateHelper.replaceParagraphsWhere(
      documentXml,
      (text) =>
          text.contains('المحاضر') &&
          text.contains('القسم') &&
          text.contains('المستوى'),
      (_) =>
          'المحاضر  : $lecturerName       القسم : $departmentName           المستوى  : $levelLabel',
    );
    documentXml = DocxTemplateHelper.replaceParagraphsWhere(
      documentXml,
      (text) => text.contains('المقرر') && text.contains('الساعات المعتمدة'),
      (_) =>
          'المقرر     : $courseName      الساعات المعتمدة :  $creditHoursText',
    );

    final tables = DocxTemplateHelper.extractTopLevelTables(documentXml);
    if (tables.isEmpty) {
      throw Exception('قالب الخطة الدراسية لا يحتوي على الجدول المتوقع.');
    }
    final tableXml = _fillMainTable(
      tables.first.xml,
      weekRanges: weekRanges,
      entries: entries,
    );
    documentXml = documentXml.replaceRange(
      tables.first.start,
      tables.first.end,
      tableXml,
    );

    return DocxTemplateHelper.repackDocx(
      loaded.archive,
      utf8.encode(documentXml),
    );
  }

  String _fillMainTable(
    String tableXml, {
    required List<String> weekRanges,
    required List<CourseStudyPlanEntry> entries,
  }) {
    final rows = DocxTemplateHelper.splitRows(tableXml);
    if (rows.isEmpty) return tableXml;

    final filledRows = <String>[];
    var weekIndex = 0;

    for (final row in rows) {
      final cells = DocxTemplateHelper.splitCells(row);
      if (cells.isEmpty) {
        filledRows.add(row);
        continue;
      }
      final firstCellText = DocxTemplateHelper.extractText(cells.first).trim();
      final weekNumber = int.tryParse(firstCellText);
      if (weekNumber == null) {
        filledRows.add(row);
        continue;
      }

      var rowXml = row;
      final weekRange =
          weekIndex < weekRanges.length ? weekRanges[weekIndex].trim() : '';
      final entry = weekIndex < entries.length
          ? entries[weekIndex]
          : const CourseStudyPlanEntry(
              topicDetails: '',
              theoryHours: '',
              practicalOrDiscussionHours: '',
              notes: '',
            );
      if (cells.length >= 2) {
        rowXml = DocxTemplateHelper.setCellText(rowXml, 1, weekRange);
      }
      if (cells.length >= 3) {
        rowXml = DocxTemplateHelper.setCellText(rowXml, 2, entry.topicDetails);
      }
      if (cells.length >= 4) {
        rowXml = DocxTemplateHelper.setCellText(rowXml, 3, entry.theoryHours);
      }
      if (cells.length >= 5) {
        rowXml = DocxTemplateHelper.setCellText(
          rowXml,
          4,
          entry.practicalOrDiscussionHours,
        );
      }
      if (cells.length >= 6) {
        rowXml = DocxTemplateHelper.setCellText(rowXml, 5, entry.notes);
      }
      filledRows.add(rowXml);
      weekIndex++;
    }

    return DocxTemplateHelper.replaceTableRows(tableXml, filledRows);
  }

  static String _submissionId(String facultyDocId, String courseId) =>
      '${facultyDocId.trim()}__${courseId.trim()}';

  static String _studentGroupLabel(CourseStudyPlanSubmission submission) {
    final parts = <String>[
      if (submission.programName.trim().isNotEmpty) submission.programName,
      if (submission.levelLabel.trim().isNotEmpty) submission.levelLabel,
    ];
    return parts.isEmpty ? submission.departmentName : parts.join(' - ');
  }

  static String _termLabel(String term) =>
      term == 'second' ? 'الفصل الثاني' : 'الفصل الأول';
}
