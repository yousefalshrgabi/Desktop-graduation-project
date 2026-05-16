/// Display order for timetable rows (Sunday-first week).
const List<String> kArabicWeekdayOrder = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

/// Maps FET short day codes (Su, Mo, …) to full Arabic weekday names.
const Map<String, String> fetDayCodeToArabic = {
  'su': 'الأحد',
  'mo': 'الاثنين',
  'tu': 'الثلاثاء',
  'we': 'الأربعاء',
  'th': 'الخميس',
  'fr': 'الجمعة',
  'sa': 'السبت',
};

/// Converts a raw day cell from CSV to Arabic. Already-Arabic text is returned trimmed.
String mapFetDayToArabic(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final key = trimmed.toLowerCase();
  if (key.length <= 3 && fetDayCodeToArabic.containsKey(key)) {
    return fetDayCodeToArabic[key]!;
  }

  // Full English weekday names sometimes appear in exports
  const english = {
    'sunday': 'الأحد',
    'monday': 'الاثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
    'saturday': 'السبت',
  };
  final lower = key.replaceAll(RegExp(r'\s+'), ' ');
  if (english.containsKey(lower)) return english[lower]!;

  return trimmed;
}
