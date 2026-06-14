/// Heuristics for program/track names from uploaded file names.
class StudyPlanFileHints {
  static String? programFromFileName(String fileName) {
    var name = fileName.replaceAll(
      RegExp(r'\.(xlsx|xls|xlsm)$', caseSensitive: false),
      '',
    );
    name = name.replaceAll('خطة برنامج', '').replaceAll('خطة', '').trim();
    final trackSep = RegExp(r'\s*[-–]\s*مسار\s*');
    if (trackSep.hasMatch(name)) {
      name = name.split(trackSep).first.trim();
    }
    return name.isEmpty ? null : name;
  }

  static String? trackFromFileName(String fileName) {
    final match = RegExp(
      r'مسار\s*(.+?)(?:\.xlsx|\.xls|$)',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (match == null) return null;
    return match.group(1)?.replaceAll(RegExp(r'[.\s]+$'), '').trim();
  }
}
