/// Whether faculty for a course is picked from the college or university-wide pool.
enum CourseCoverageScope {
  college,
  university;

  String get firestoreValue => name;

  String get labelAr => switch (this) {
        CourseCoverageScope.college => 'تُغطى من الكلية',
        CourseCoverageScope.university => 'تُغطى من خارج الكلية (جامعة)',
      };

  static CourseCoverageScope fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'university' || v == 'جامعة' || v == 'خارج') {
      return CourseCoverageScope.university;
    }
    return CourseCoverageScope.college;
  }

  /// Default from study-plan «نوع المقرر» column.
  static CourseCoverageScope inferFromCourseType(String courseTypeAr) {
    final n = courseTypeAr
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    if (n.contains('جامعة') ||
        n.contains('univ') ||
        n.contains('university')) {
      return CourseCoverageScope.university;
    }
    return CourseCoverageScope.college;
  }
}
