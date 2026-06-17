import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

import 'package:academic_affairs_management/features/desktop_pages/workload_management/models/graduation_project_group.dart';
import '../models/timetable_entry.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/graduation_project_firestore_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/utils/app_file_saver.dart';
import '../utils/fet_day_mapping.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/utils/level_labels.dart';
import '../utils/timetable_schedule_grid.dart';

/// Fills the official teacher timetable Word template from assets.
class TeacherWordExportService {
  static const _templateAsset =
      'assets/templates/teacher time table tampelete.docx';

  static const _checkMark = '✓';

  TeacherWordExportService({
    GraduationProjectFirestoreService? gradProject,
  }) : _gradProject = gradProject ?? GraduationProjectFirestoreService();

  final GraduationProjectFirestoreService _gradProject;

  /// Maps Arabic weekday to subject/room row indices in the main timetable table.
  static const Map<String, (int subjectRow, int roomRow)> _dayRows = {
    'الأحد': (2, 3),
    'الاثنين': (4, 5),
    'الثلاثاء': (6, 7),
    'الأربعاء': (8, 9),
    'الاربعاء': (8, 9),
    'الخميس': (10, 11),
  };

  /// Attendance table: day column index (0–4) for Sunday–Thursday.
  static const Map<String, int> _attendanceCols = {
    'الأحد': 0,
    'الاثنين': 1,
    'الثلاثاء': 2,
    'الأربعاء': 3,
    'الاربعاء': 3,
    'الخميس': 4,
  };

  Future<void> exportTeacherSchedule({
    required String teacherName,
    required List<TimetableEntry> entries,
  }) async {
    final filtered = entries
        .where((e) => e.teachers.any((t) => t.trim() == teacherName.trim()))
        .toList();
    final gradGroups = (await _gradProject.getGroupsForTeacher(teacherName))
        .where((group) => !group.isParallel)
        .toList();

    if (filtered.isEmpty && gradGroups.isEmpty) {
      throw Exception('لا توجد بيانات لهذا المعلم');
    }

    final templateBytes = await rootBundle.load(_templateAsset);
    final decoded = ZipDecoder().decodeBytes(
      templateBytes.buffer.asUint8List(),
    );

    final docFile = decoded.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('ملف القالب غير صالح'),
    );
    var documentXml = utf8.decode(docFile.content as List<int>);

    documentXml = _replaceTeacherName(documentXml, teacherName);

    final tables = _extractTopLevelTables(documentXml);
    if (tables.length < 2) {
      throw Exception('بنية القالب غير متوقعة (جداول ناقصة)');
    }

    final scheduleFill = _fillScheduleTable(
      tables[0].xml,
      filtered,
      gradGroups,
    );
    final attendanceTable = _fillAttendanceTable(
      tables[1].xml,
      filtered,
      extraWorkingDays: scheduleFill.extraWorkingDays,
    );

    // Replace from end → start so byte offsets stay valid after the first edit.
    documentXml = documentXml.replaceRange(
      tables[1].start,
      tables[1].end,
      attendanceTable,
    );
    documentXml = documentXml.replaceRange(
      tables[0].start,
      tables[0].end,
      scheduleFill.tableXml,
    );

    final updatedDocument = utf8.encode(documentXml);
    final outBytes = _repackDocx(decoded, updatedDocument);

    final safeName = teacherName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await AppFileSaver.saveExportedFile(
      name: 'جدول_المعلم_$safeName',
      bytes: Uint8List.fromList(outBytes),
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  /// Rebuilds the DOCX by reusing original archive entries (only document.xml changes).
  static List<int> _repackDocx(Archive decoded, List<int> documentXml) {
    final outputArchive = Archive();
    for (final file in decoded.files) {
      if (!file.isFile) continue;
      if (file.name == 'word/document.xml') {
        outputArchive.addFile(
          ArchiveFile(file.name, documentXml.length, documentXml),
        );
      } else {
        outputArchive.addFile(file);
      }
    }
    final encoded = ZipEncoder().encode(outputArchive);
    if (encoded == null) {
      throw Exception('فشل في توليد ملف Word');
    }
    return encoded;
  }

  String _replaceTeacherName(String xml, String teacherName) {
    final escaped = _escapeXml(_sanitizeText(teacherName));
    var result = xml;
    for (final placeholder in const [
      '<اسم المعلم>',
      '&lt;اسم المعلم&gt;',
    ]) {
      result = result.replaceAll(placeholder, escaped);
    }
    return result;
  }

  _ScheduleFillResult _fillScheduleTable(
    String tableXml,
    List<TimetableEntry> entries,
    List<GraduationProjectGroup> gradGroups,
  ) {
    final rows = _splitRows(tableXml);
    if (rows.length < 12) {
      throw Exception('جدول المحاضرات في القالب غير مكتمل');
    }

    final hours = TimetableScheduleGrid.sortedHours(entries.map((e) => e.hour));
    final hourToSlot = <String, int>{
      for (var i = 0; i < hours.length && i < 3; i++) hours[i]: i,
    };

    final subjectCells = <String, List<_SubjectScheduleLabel>>{};
    final roomCells = <String, List<String>>{};
    final occupiedSlots = <String>{};

    for (final e in entries) {
      final dayKey = _normalizeDay(e.day);
      final slot = hourToSlot[e.hour];
      if (dayKey == null || slot == null) continue;
      final key = '$dayKey|$slot';
      occupiedSlots.add(key);
      subjectCells
          .putIfAbsent(key, () => [])
          .add(_SubjectScheduleLabel.fromEntry(e));
      roomCells.putIfAbsent(key, () => []).add(e.room);
    }

    final extraWorkingDays = <String>{};
    for (final group in gradGroups) {
      final key = _firstEmptySlot(occupiedSlots);
      if (key == null) break;
      occupiedSlots.add(key);
      subjectCells[key] = [_SubjectScheduleLabel.projectGroup(group)];
      roomCells[key] = const [''];
      extraWorkingDays.add(key.split('|').first);
    }

    for (final dayKey in _dayRows.keys) {
      final rowPair = _dayRows[dayKey];
      if (rowPair == null) continue;

      for (var slot = 0; slot < 3; slot++) {
        final key = '$dayKey|$slot';
        final subject = _formatSubjectCell(subjectCells[key] ?? const []);
        final room = _joinUnique(roomCells[key] ?? const []);
        if (subject.isNotEmpty) {
          rows[rowPair.$1] = _setCellText(rows[rowPair.$1], 2 + slot, subject);
        }
        if (room.isNotEmpty) {
          rows[rowPair.$2] = _setCellText(rows[rowPair.$2], 2 + slot, room);
        }
      }
    }

    return _ScheduleFillResult(_joinRows(tableXml, rows), extraWorkingDays);
  }

  String _fillAttendanceTable(
    String tableXml,
    List<TimetableEntry> entries, {
    Set<String> extraWorkingDays = const {},
  }) {
    final rows = _splitRows(tableXml);
    if (rows.length < 2) {
      throw Exception('جدول أيام التواجد في القالب غير مكتمل');
    }

    final workingDays =
        entries.map((e) => _normalizeDay(e.day)).whereType<String>().toSet();
    workingDays.addAll(extraWorkingDays);

    for (final day in workingDays) {
      final col = _attendanceCols[day];
      if (col == null) continue;
      rows[1] = _setCellText(rows[1], col, _checkMark);
    }

    return _joinRows(tableXml, rows);
  }

  String? _normalizeDay(String raw) {
    final arabic = mapFetDayToArabic(raw);
    if (arabic.isEmpty) return null;
    if (_dayRows.containsKey(arabic)) return arabic;
    if (arabic == 'الأربعاء') return 'الاربعاء';
    return arabic;
  }

  String _joinUnique(List<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final v in values) {
      final t = _sanitizeText(v);
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      out.add(t);
    }
    return out.join('\n');
  }

  String _formatSubjectCell(List<_SubjectScheduleLabel> values) {
    final bySubject = <String, Map<String, Set<String>>>{};
    final subjectOrder = <String>[];

    for (final value in values) {
      final subject = _sanitizeText(value.subject).trim();
      if (subject.isEmpty) continue;

      final programs = bySubject.putIfAbsent(subject, () {
        subjectOrder.add(subject);
        return <String, Set<String>>{};
      });

      for (final context in value.contexts) {
        final program = _sanitizeText(context.program).trim();
        final level = _sanitizeText(context.level).trim();
        if (program.isEmpty || level.isEmpty) continue;
        programs.putIfAbsent(program, () => <String>{}).add(level);
      }
    }

    final lines = <String>[];
    for (final subject in subjectOrder) {
      lines.add(subject);

      final programs = bySubject[subject]!;
      for (final entry in programs.entries) {
        final levels = entry.value.toList()..sort(_compareLevels);
        if (levels.isEmpty) {
          lines.add(entry.key);
        } else {
          lines.add('${entry.key} - ${levels.join('، ')}');
        }
      }
    }

    return lines.join('\n');
  }

  static int _compareLevels(String a, String b) {
    final aLevel = LevelLabels.parseLevel(a);
    final bLevel = LevelLabels.parseLevel(b);
    if (aLevel != null && bLevel != null && aLevel != bLevel) {
      return aLevel.compareTo(bLevel);
    }
    return a.compareTo(b);
  }

  String? _firstEmptySlot(Set<String> occupiedSlots) {
    for (final day in _dayRows.keys) {
      for (var slot = 0; slot < 3; slot++) {
        final key = '$day|$slot';
        if (!occupiedSlots.contains(key)) return key;
      }
    }
    return null;
  }

  /// Removes characters illegal in XML 1.0 text nodes.
  static String _sanitizeText(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static List<_TableSpan> _extractTopLevelTables(String xml) {
    final spans = <_TableSpan>[];
    var depth = 0;
    int? start;
    for (var i = 0; i < xml.length; i++) {
      if (xml.startsWith('<w:tbl>', i)) {
        if (depth == 0) start = i;
        depth++;
        i += 6;
      } else if (xml.startsWith('</w:tbl>', i)) {
        depth--;
        if (depth == 0 && start != null) {
          final end = i + 8;
          spans.add(_TableSpan(start, end, xml.substring(start, end)));
          start = null;
        }
        i += 7;
      }
    }
    return spans;
  }

  static List<String> _splitRows(String tableXml) {
    return RegExp(r'<w:tr[^>]*>.*?</w:tr>', dotAll: true)
        .allMatches(tableXml)
        .map((m) => m.group(0)!)
        .toList();
  }

  static String _joinRows(String tableXml, List<String> rows) {
    var index = 0;
    return tableXml.replaceAllMapped(
      RegExp(r'<w:tr[^>]*>.*?</w:tr>', dotAll: true),
      (match) {
        if (index >= rows.length) return match.group(0)!;
        return rows[index++];
      },
    );
  }

  static List<String> _splitCells(String rowXml) {
    return RegExp(r'<w:tc[^>]*>.*?</w:tc>', dotAll: true)
        .allMatches(rowXml)
        .map((m) => m.group(0)!)
        .toList();
  }

  static String _setCellText(String rowXml, int cellIndex, String text) {
    final cells = _splitCells(rowXml);
    if (cellIndex < 0 || cellIndex >= cells.length) return rowXml;
    cells[cellIndex] = _setCellContent(cells[cellIndex], text);
    var cellIndexWalk = 0;
    return rowXml.replaceAllMapped(
      RegExp(r'<w:tc[^>]*>.*?</w:tc>', dotAll: true),
      (match) {
        if (cellIndexWalk >= cells.length) return match.group(0)!;
        return cells[cellIndexWalk++];
      },
    );
  }

  /// Writes text into the first paragraph of a table cell using Word line breaks.
  static String _setCellContent(String cellXml, String text) {
    final sanitized = _sanitizeText(text);
    final paragraphMatch =
        RegExp(r'<w:p[^>]*>.*?</w:p>', dotAll: true).firstMatch(cellXml);

    if (paragraphMatch == null) {
      final runs = _buildRunsXml(sanitized);
      return cellXml.replaceFirst(
        '</w:tc>',
        '<w:p>$runs</w:p></w:tc>',
      );
    }

    final paragraph = paragraphMatch.group(0)!;
    final pPr = RegExp(r'<w:pPr[^>]*>.*?</w:pPr>', dotAll: true)
            .firstMatch(paragraph)
            ?.group(0) ??
        '';
    final rPr = RegExp(r'<w:rPr[^>]*>.*?</w:rPr>', dotAll: true)
            .firstMatch(paragraph)
            ?.group(0) ??
        '';

    final runs = _buildRunsXml(sanitized, rPr: rPr);
    final newParagraph = '<w:p>$pPr$runs</w:p>';
    return cellXml.replaceFirst(paragraph, newParagraph);
  }

  static String _buildRunsXml(String text, {String rPr = ''}) {
    if (text.isEmpty) {
      return '<w:r>$rPr<w:t></w:t></w:r>';
    }

    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final escaped = _escapeXml(lines[i]);
      buffer.write('<w:r>$rPr<w:t xml:space="preserve">$escaped</w:t></w:r>');
      if (i < lines.length - 1) {
        buffer.write('<w:r>$rPr<w:br /></w:r>');
      }
    }
    return buffer.toString();
  }
}

class _TableSpan {
  const _TableSpan(this.start, this.end, this.xml);

  final int start;
  final int end;
  final String xml;
}

class _ScheduleFillResult {
  const _ScheduleFillResult(this.tableXml, this.extraWorkingDays);

  final String tableXml;
  final Set<String> extraWorkingDays;
}

class _SubjectScheduleLabel {
  const _SubjectScheduleLabel({
    required this.subject,
    required this.contexts,
  });

  factory _SubjectScheduleLabel.fromEntry(TimetableEntry entry) {
    final contexts = <_StudentSetContext>[];
    final seen = <String>{};

    for (final rawSet in entry.studentSets) {
      for (final part in rawSet.split('+')) {
        final context = _StudentSetContext.tryParse(part);
        if (context == null) continue;
        final key = '${context.program}|${context.level}';
        if (seen.add(key)) contexts.add(context);
      }
    }

    return _SubjectScheduleLabel(
      subject: entry.subject,
      contexts: contexts,
    );
  }

  factory _SubjectScheduleLabel.projectGroup(GraduationProjectGroup group) {
    return _SubjectScheduleLabel(
      subject:
          'مشروع تخرج - مجموعة ${group.groupNumber}\n${group.studentCount} طالب',
      contexts: const [],
    );
  }

  final String subject;
  final List<_StudentSetContext> contexts;
}

class _StudentSetContext {
  const _StudentSetContext({
    required this.program,
    required this.level,
  });

  static _StudentSetContext? tryParse(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'\bG\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bgroup\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'مجموعة\s*\d+'), '')
        .replaceAll('موازي', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = cleaned
        .replaceAll(RegExp(r'\s*-\s*$'), '')
        .replaceAll(RegExp(r'^\s*-\s*'), '')
        .trim();

    if (cleaned.isEmpty) return null;

    final separator = RegExp(r'\s+-\s+').allMatches(cleaned).toList();
    if (separator.isEmpty) return null;

    final lastSeparator = separator.last;
    final program = cleaned.substring(0, lastSeparator.start).trim();
    final levelRaw = cleaned.substring(lastSeparator.end).trim();
    if (program.isEmpty || levelRaw.isEmpty) return null;

    final parsedLevel = LevelLabels.parseLevel(levelRaw);
    return _StudentSetContext(
      program: program,
      level: parsedLevel == null ? levelRaw : LevelLabels.forLevel(parsedLevel),
    );
  }

  final String program;
  final String level;
}
