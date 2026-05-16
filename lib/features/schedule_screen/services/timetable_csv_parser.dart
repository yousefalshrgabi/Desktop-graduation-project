import '../models/timetable_entry.dart';
import '../utils/fet_day_mapping.dart';

/// Parses FET-exported timetable CSV into [TimetableEntry] rows.
///
/// Expected columns (case-insensitive; extra columns are ignored):
/// - id / activity id / #
/// - day
/// - hour
/// - subject
/// - teachers / teacher
/// - student sets / students / studentSets (cell split on '+')
/// - room
class TimetableCsvParser {
  const TimetableCsvParser();

  /// Parses full file contents (UTF-8 string) without external csv dependency.
  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;
      rows.add(_parseCsvLine(trimmed));
    }
    return rows;
  }

  /// Handles quoted fields with commas inside them.
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString().trim());
    return fields;
  }

  /// Parses full file contents (UTF-8 string).
  List<TimetableEntry> parse(String csvText) {
    var text = csvText.trimLeft();
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    text = _normalizeNewlines(text);
    final rows = _parseCsv(text);
    if (rows.isEmpty) return [];

    final headerRow = rows.first.map((e) => e.toString()).toList();
    final indices = _HeaderIndices.fromHeaders(headerRow);

    final out = <TimetableEntry>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i].map((e) => e.toString()).toList();
      final entry = _rowToEntry(indices, row, i);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  TimetableEntry? _rowToEntry(_HeaderIndices idx, List<String> row, int rowIndex) {
    String cell(int? i) {
      if (i == null || i < 0 || i >= row.length) return '';
      return row[i].trim();
    }

    final idRaw = cell(idx.id);
    final dayRaw = cell(idx.day);
    final hourRaw = cell(idx.hour);
    final subjectRaw = cell(idx.subject);
    final teachersRaw = cell(idx.teachers);
    final studentSetsRaw = cell(idx.studentSets);
    final roomRaw = cell(idx.room);

    if (dayRaw.isEmpty && hourRaw.isEmpty && subjectRaw.isEmpty) {
      return null;
    }

    final id = idRaw.isNotEmpty ? idRaw : 'row_$rowIndex';

    return TimetableEntry(
      id: id,
      day: mapFetDayToArabic(dayRaw),
      hour: hourRaw,
      subject: subjectRaw,
      teachers: _splitTeachers(teachersRaw),
      studentSets: _splitStudentSets(studentSetsRaw),
      room: roomRaw,
    );
  }

  static List<String> _splitStudentSets(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split('+')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<String> _splitTeachers(String raw) {
    if (raw.trim().isEmpty) return [];
    final parts = raw.split(RegExp(r'[,،;؛]'));
    return parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}

class _HeaderIndices {
  _HeaderIndices({
    required this.id,
    required this.day,
    required this.hour,
    required this.subject,
    required this.teachers,
    required this.studentSets,
    required this.room,
  });

  final int? id;
  final int? day;
  final int? hour;
  final int? subject;
  final int? teachers;
  final int? studentSets;
  final int? room;

  factory _HeaderIndices.fromHeaders(List<String> headers) {
    final norm = headers.map(_normalizeHeader).toList();

    int? findFirst(Set<String> aliases) {
      for (var i = 0; i < norm.length; i++) {
        if (aliases.contains(norm[i])) return i;
      }
      return null;
    }

    return _HeaderIndices(
      id: findFirst({'id', 'activityid', 'activity id', 'activity_id', 'activity', '#', 'no'}),
      day: findFirst({'day', 'days'}),
      hour: findFirst({'hour', 'slot', 'time', 'period'}),
      subject: findFirst({'subject', 'subjects'}),
      teachers: findFirst({'teachers', 'teacher', 'teacher(s)'}),
      studentSets: findFirst({
        'studentsets', 'students', 'students sets',
        'studentssets', 'student sets', 'groups', 'sets',
      }),
      room: findFirst({'room', 'rooms', 'place', 'venue'}),
    );
  }
}

String _normalizeHeader(String h) {
  return h
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('_', ' ');
}

String _normalizeNewlines(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
