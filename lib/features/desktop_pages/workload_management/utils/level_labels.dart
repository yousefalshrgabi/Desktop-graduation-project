/// Arabic labels and normalization for academic levels (مستوى).
class LevelLabels {
  static const Map<int, String> ar = {
    1: 'المستوى الأول',
    2: 'المستوى الثاني',
    3: 'المستوى الثالث',
    4: 'المستوى الرابع',
    5: 'المستوى الخامس',
    6: 'المستوى السادس',
    7: 'المستوى السابع',
    8: 'المستوى الثامن',
  };

  static String forLevel(int level) => ar[level] ?? 'المستوى $level';

  static int semesterNumber(int level, String? term) {
    return ((level - 1) * 2) + (term == 'second' ? 2 : 1);
  }

  static String semesterLabel(int semesterNumber) {
    final level = ((semesterNumber - 1) ~/ 2) + 1;
    final term = semesterNumber.isOdd ? 'الفصل الأول' : 'الفصل الثاني';
    return '${forLevel(level)} - $term';
  }

  /// Short label used in incentive/nasab files (اول، ثاني، …).
  static String nasabShort(int level) {
    const map = {
      1: 'اول',
      2: 'ثاني',
      3: 'ثالث',
      4: 'رابع',
      5: 'خامس',
      6: 'سادس',
      7: 'سابع',
      8: 'ثامن',
    };
    return map[level] ?? '$level';
  }

  /// Parses nasab/plan level strings: اول، تاني، ثاني، رابع شبكات...
  static int? parseLevel(String raw) {
    final n = raw.trim().replaceAll('ـ', '').replaceAll(' ', '').toLowerCase();
    if (n.isEmpty) return null;

    const map = {
      'اول': 1,
      'الاول': 1,
      'أول': 1,
      'الأول': 1,
      '1': 1,
      'تاني': 2,
      'ثاني': 2,
      'الثاني': 2,
      '2': 2,
      'ثالث': 3,
      'الثالث': 3,
      '3': 3,
      'رابع': 4,
      'الرابع': 4,
      '4': 4,
      'خامس': 5,
      'الخامس': 5,
      '5': 5,
      'سادس': 6,
      '6': 6,
      'سابع': 7,
      '7': 7,
      'ثامن': 8,
      '8': 8,
    };

    for (final entry in map.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return int.tryParse(n);
  }
}
