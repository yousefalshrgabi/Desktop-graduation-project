import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../models/study_plan.dart';
import '../utils/course_coverage.dart';

/// Parses university study-plan Excel workbooks (خطة برنامج …).
class StudyPlanParser {
  StudyPlan parseBytes(
    List<int> bytes, {
    required String collegeName,
    String? defaultProgramName,
    String? defaultTrackName,
    String? sourceFileName,
  }) {
    final workbook = SpreadsheetDecoder.decodeBytes(bytes);
    String? programName = defaultProgramName;
    String? trackName = defaultTrackName;
    String? degreeAr;
    String? degreeEn;
    String? planYear;

    final semesters = <StudyPlanSemester>[];

    for (final sheetName in workbook.tables.keys) {
      final sheet = workbook.tables[sheetName]!;
      if (sheet.rows.isEmpty) continue;

      final meta = _extractMetadata(sheet);
      programName ??= meta.programName;
      trackName ??= meta.trackName;
      degreeAr ??= meta.degreeAr;
      degreeEn ??= meta.degreeEn;
      planYear ??= meta.planYear;

      semesters.addAll(
        _parseSheetSemesters(sheet, sheetName: sheetName),
      );
    }

    final resolvedProgram = (programName ?? defaultProgramName ?? '').trim();
    if (resolvedProgram.isEmpty) {
      throw const FormatException(
        'تعذر العثور على اسم البرنامج في ملف Excel. يرجى إدخاله يدوياً.',
      );
    }

    return StudyPlan(
      collegeName: collegeName.trim(),
      programName: resolvedProgram,
      trackName: (trackName ?? defaultTrackName ?? '').trim(),
      degreeNameAr: degreeAr,
      degreeNameEn: degreeEn,
      planStartYear: planYear,
      semesters: semesters,
      sourceFileName: sourceFileName,
    );
  }

  List<StudyPlanSemester> _parseSheetSemesters(
    SpreadsheetTable sheet, {
    required String sheetName,
  }) {
    final list = <StudyPlanSemester>[];
    _ParsedSemesterHeader? currentHeader;
    var currentCourses = <StudyPlanCourse>[];
    var sequenceCounter = 1;

    for (final row in sheet.rows) {
      if (row.isEmpty) continue;

      // الحل الذكي: دمج السطر بالكامل في نص واحد للبحث عن الكلمات المفتاحية للفصل الدراسي
      final rowText = row.map((e) => e?.toString() ?? '').join(' ');

      if (rowText.contains('المستوى') ||
          rowText.contains('الفصل') ||
          rowText.contains('Level') ||
          rowText.contains('Semester')) {
        if (currentHeader != null && currentCourses.isNotEmpty) {
          list.add(
            StudyPlanSemester(
              key: currentHeader.key,
              labelAr: currentHeader.labelAr,
              labelEn: currentHeader.labelEn ?? currentHeader.labelAr,
              level: currentHeader.level ?? 1,
              term: currentHeader.term,
              courses: currentCourses,
            ),
          );
        }
        currentHeader = _parseSemesterHeader(row, sheetName: sheetName);
        currentCourses = [];
        sequenceCounter = 1;
        continue;
      }

      final course = _parseCourseRow(row, sequence: sequenceCounter);
      if (course != null) {
        currentCourses.add(course);
        sequenceCounter++;
      }
    }

    if (currentHeader != null && currentCourses.isNotEmpty) {
      list.add(
        StudyPlanSemester(
          key: currentHeader.key,
          labelAr: currentHeader.labelAr,
          labelEn: currentHeader.labelEn ?? currentHeader.labelAr,
          level: currentHeader.level ?? 1,
          term: currentHeader.term,
          courses: currentCourses,
        ),
      );
    }

    return list;
  }

  StudyPlanCourse? _parseCourseRow(List<dynamic> row, {required int sequence}) {
    if (row.length < 12) return null;

    // الفهارس الحقيقية بناءً على عينة الـ CSV المرفقة من قبلك
    final typeAr = row[3]?.toString().trim() ?? '';
    final nameAr = row[4]?.toString().trim() ?? '';
    final codeLocal = row[5]?.toString().trim() ?? '';
    final codeEn = row.length > 14 ? row[14]?.toString().trim() : null;
    final titleEn = row.length > 15 ? row[15]?.toString().trim() : null;

    // خانات المقررات الاختيارية في نموذج الخطة لا تحتوي على رمز مقرر بعد.
    // نقبلها باسمها حتى تظهر في الخطة، مع إبقاء الرمز إلزامياً للمقررات العادية.
    final isElectivePlaceholder = _isElectivePlaceholder(nameAr, titleEn);
    if (nameAr.isEmpty ||
        typeAr.isEmpty ||
        (codeLocal.isEmpty && !isElectivePlaceholder)) {
      return null;
    }

    // التحقق من أن خانة الرقم التسلسلي تحتوي على رقم فعلاً لاستبعاد أسطر العناوين مثل (الساعات المعتمدة)
    final seqStr = row[2]?.toString().trim() ?? '';
    if (int.tryParse(seqStr) == null) return null;

    // قراءة الساعات المعتمدة بدقة من الفهارس 6 و 7 و 8
    final creditTheory = _parseInt(row[6]) ?? 0;
    final creditPractical = _parseInt(row[7]) ?? 0;
    final creditDiscussion = _parseInt(row[8]) ?? 0;

    // حساب مجموع الساعات المعتمدة الفعلي برمجياً بشكل سليم
    final calculatedTotal = creditTheory + creditPractical + creditDiscussion;

    // قراءة الساعات الفعلية الخاصة بالنصاب التدريسي من الفهارس 10 و 11
    final actualTheory = _parseInt(row[10]) ?? 0;
    final actualPractical = _parseInt(row[11]) ?? 0;

    var scope = CourseCoverageScope.college;
    if (typeAr.contains('جامعة')) {
      scope = CourseCoverageScope.university;
    }

    return StudyPlanCourse(
      codeLocal: codeLocal,
      nameAr: nameAr,
      titleEn: titleEn ?? '',
      codeEn: codeEn ?? '',
      courseTypeAr: typeAr,
      courseTypeEn: typeAr.contains('جامعة')
          ? 'Univ.'
          : (typeAr.contains('كلية') ? 'Coll.' : 'Dep.'),
      creditTheory: creditTheory,
      creditPractical: creditPractical,
      creditDiscussion: creditDiscussion,
      creditTotal: calculatedTotal > 0 ? calculatedTotal : creditTheory,
      actualTheory: actualTheory,
      actualPractical: actualPractical,
      actualDiscussion: 0,
      actualTraining: 0,
      coverageScope: scope,
      sequence: sequence,
      notes: '',
    );
  }

  bool _isElectivePlaceholder(String nameAr, String? titleEn) {
    final arabic = nameAr.replaceAll(RegExp(r'\s+'), ' ').trim();
    final english = (titleEn ?? '').toLowerCase().trim();
    return arabic.contains('اختياري') || english.contains('elective course');
  }

  _SheetMeta _extractMetadata(SpreadsheetTable sheet) {
    String? program;
    String? track;
    String? degAr;
    String? degEn;
    String? year;

    for (var i = 0; i < sheet.rows.length && i < 15; i++) {
      final row = sheet.rows[i];
      for (final cell in row) {
        if (cell == null) continue;
        final txt = cell.toString();
        if (txt.contains('برنامج')) {
          program = txt.replaceAll(RegExp(r'.*برنامج[:\s]*'), '').trim();
        } else if (txt.contains('مسار')) {
          track = txt.replaceAll(RegExp(r'.*مسار[:\s]*'), '').trim();
        } else if (txt.contains('درجة')) {
          degAr = txt.trim();
        } else if (txt.contains('Degree')) {
          degEn = txt.trim();
        } else if (txt.contains('بدء العمل')) {
          year = txt.replaceAll(RegExp(r'.*الخطة[:\s]*'), '').trim();
        }
      }
    }

    return _SheetMeta(
      programName: program,
      trackName: track,
      degreeAr: degAr,
      degreeEn: degEn,
      planYear: year,
    );
  }

  _ParsedSemesterHeader _parseSemesterHeader(
    List<dynamic> row, {
    required String sheetName,
  }) {
    // دمج السطر بالكامل للوصول لنص الترويسة أينما كان موقعه في الأعمدة الأولى
    final line = row.map((e) => e?.toString() ?? '').join(' ');
    var level = 0;
    var term = 'first';
    var labelAr = line.trim();

    // استخراج المسمى العربي النظيف للسطر المدمج وعرضه بشكل جميل بالواجهة
    for (final cell in row) {
      final cellStr = cell?.toString().trim() ?? '';
      if (cellStr.contains('المستوى') || cellStr.contains('الفصل')) {
        labelAr = cellStr;
        break;
      }
    }

    final matches =
        RegExp(r'(الأول|الثاني|الثالث|الرابع|الخامس|السادس|السابع|الثامن)')
            .allMatches(line);
    if (matches.isNotEmpty) {
      level = _arabicOrdinalToInt(matches.first.group(0)!);
    } else {
      final engMatches = RegExp(
        r'(first|second|third|fourth|fifth|sixth|seventh|eighth)',
        caseSensitive: false,
      ).allMatches(line);
      if (engMatches.isNotEmpty) {
        level = _englishLevelToInt(engMatches.first.group(0)!);
      }
    }

    final n = line.toLowerCase();
    if (n.contains('الثاني') ||
        n.contains('secondsemester') ||
        n.contains('2ndsemester')) {
      term = 'second';
    }

    final key = 'L${level}_$term';
    return _ParsedSemesterHeader(
      key: key,
      labelAr: labelAr,
      labelEn: line.contains('Level') ? line : null,
      level: level == 0 ? null : level,
      term: term,
    );
  }

  int _arabicOrdinalToInt(String word) {
    const map = {
      'الأول': 1,
      'الثاني': 2,
      'الثالث': 3,
      'الرابع': 4,
      'الخامس': 5,
      'السادس': 6,
      'السابع': 7,
      'الثامن': 8,
    };
    return map[word] ?? 0;
  }

  int _englishLevelToInt(String word) {
    const map = {
      'first': 1,
      'second': 2,
      'third': 3,
      'fourth': 4,
      'fifth': 5,
      'sixth': 6,
      'seventh': 7,
      'eighth': 8,
    };
    return map[word.toLowerCase()] ?? 0;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }
}

class _SheetMeta {
  const _SheetMeta({
    this.programName,
    this.trackName,
    this.degreeAr,
    this.degreeEn,
    this.planYear,
  });
  final String? programName;
  final String? trackName;
  final String? degreeAr;
  final String? degreeEn;
  final String? planYear;
}

class _ParsedSemesterHeader {
  const _ParsedSemesterHeader({
    required this.key,
    required this.labelAr,
    this.labelEn,
    this.level,
    required this.term,
  });
  final String key;
  final String labelAr;
  final String? labelEn;
  final int? level;
  final String term;
}
