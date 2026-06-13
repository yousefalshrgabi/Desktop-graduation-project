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
  /// Parses full file contents (UTF-8 string).
  List<TimetableEntry> parse(String csvText) {
    var text = csvText.trimLeft();
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    
    final rows = _parseCsv(text);
    if (rows.isEmpty) return [];

    final headerRow = rows.first;
    final indices = _HeaderIndices.fromHeaders(headerRow);

    final out = <TimetableEntry>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= indices.maxIndex) continue;

      final id = row[indices.id].trim();
      if (id.isEmpty) continue;

      out.add(TimetableEntry(
        id: id,
        day: mapFetDayToArabic(row[indices.day].trim()),
        hour: row[indices.hour].trim(),
        subject: row[indices.subject].trim(),
        teachers: _splitCell(row[indices.teachers]),
        studentSets: _splitCell(row[indices.studentSets], separator: '+'),
        room: row[indices.room].trim(),
        collegeName: '',
      ));
    }
    return out;
  }

  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentCell = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      
      if (c == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          // Escaped quote
          currentCell.write('"');
          i++; // Skip the second quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
      } else if ((c == '\n' || c == '\r') && !inQuotes) {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n of \r\n
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        if (currentRow.isNotEmpty || i < text.length - 1) {
          rows.add(currentRow);
          currentRow = <String>[];
        }
      } else {
        currentCell.write(c);
      }
    }
    
    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(currentRow);
    }
    
    return rows;
  }

  List<String> _splitCell(String cell, {String separator = ','}) {
    return cell
        .split(separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _HeaderIndices {
  final int id, day, hour, subject, teachers, studentSets, room;
  final int maxIndex;

  _HeaderIndices({
    required this.id,
    required this.day,
    required this.hour,
    required this.subject,
    required this.teachers,
    required this.studentSets,
    required this.room,
  }) : maxIndex = [id, day, hour, subject, teachers, studentSets, room].reduce((a, b) => a > b ? a : b);

  factory _HeaderIndices.fromHeaders(List<String> headers) {
    int hId = 0, hDay = 1, hHour = 2, hSubj = 3, hTeach = 4, hStud = 5, hRoom = 6;
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      if (h == 'id' || h == 'activity id' || h == '#') hId = i;
      else if (h == 'day' || h == 'اليوم') hDay = i;
      else if (h == 'hour' || h == 'الساعة') hHour = i;
      else if (h == 'subject' || h == 'المادة') hSubj = i;
      else if (h == 'teachers' || h == 'teacher' || h == 'المعلمين') hTeach = i;
      else if (h == 'student sets' || h == 'students' || h == 'studentsets' || h == 'الطلاب') hStud = i;
      else if (h == 'room' || h == 'القاعة') hRoom = i;
    }
    return _HeaderIndices(
      id: hId, day: hDay, hour: hHour, subject: hSubj,
      teachers: hTeach, studentSets: hStud, room: hRoom,
    );
  }
}
