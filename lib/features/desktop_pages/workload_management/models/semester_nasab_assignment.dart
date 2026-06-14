/// Row matching ورقة1 columns A (course), B (theory teacher), C (practical teacher).
const Object _keepValue = Object();

class SemesterNasabAssignment {
  const SemesterNasabAssignment({
    required this.collegeName,
    required this.term,
    required this.courseKey,
    required this.courseNameAr,
    this.codeLocal = '',
    required this.coverageScope,
    this.theoryTeacherId,
    this.theoryTeacherName = '',
    this.practicalTeacherId,
    this.practicalTeacherName = '',
    bool? mergeGroups,
  }) : mergeGroups = mergeGroups ?? (coverageScope == 'university');

  final String collegeName;
  final String term;
  final String courseKey;
  final String courseNameAr;
  final String codeLocal;
  final String coverageScope;
  final String? theoryTeacherId;
  final String theoryTeacherName;
  final String? practicalTeacherId;
  final String practicalTeacherName;
  final bool mergeGroups; // Whether to merge general and parallel groups in activities

  static String docIdFor({
    required String collegeName,
    required String term,
    required String courseKey,
  }) {
    final college = collegeName.trim().replaceAll(RegExp(r'[/\\[\]*\s]+'), '_');
    return '${college}__${term}__$courseKey';
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeName': collegeName,
      'term': term,
      'courseKey': courseKey,
      'courseNameAr': courseNameAr,
      'codeLocal': codeLocal,
      'coverageScope': coverageScope,
      'theoryTeacherId': theoryTeacherId ?? '',
      'theoryTeacherName': theoryTeacherName,
      'practicalTeacherId': practicalTeacherId ?? '',
      'practicalTeacherName': practicalTeacherName,
      'mergeGroups': mergeGroups,
      'updatedAt': null,
    };
  }

  factory SemesterNasabAssignment.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final coverageScope = (map['coverageScope'] ?? 'college').toString();
    return SemesterNasabAssignment(
      collegeName: (map['collegeName'] ?? '').toString(),
      term: (map['term'] ?? '').toString(),
      courseKey: (map['courseKey'] ?? id.split('__').last).toString(),
      courseNameAr: (map['courseNameAr'] ?? '').toString(),
      codeLocal: (map['codeLocal'] ?? '').toString(),
      coverageScope: coverageScope,
      theoryTeacherId: (map['theoryTeacherId'] ?? '').toString().isEmpty
          ? null
          : map['theoryTeacherId'].toString(),
      theoryTeacherName: (map['theoryTeacherName'] ?? '').toString(),
      practicalTeacherId: (map['practicalTeacherId'] ?? '').toString().isEmpty
          ? null
          : map['practicalTeacherId'].toString(),
      practicalTeacherName: (map['practicalTeacherName'] ?? '').toString(),
      mergeGroups:
          (map['mergeGroups'] as bool?) ?? (coverageScope == 'university'),
    );
  }

  SemesterNasabAssignment copyWith({
    Object? theoryTeacherId = _keepValue,
    String? theoryTeacherName,
    Object? practicalTeacherId = _keepValue,
    String? practicalTeacherName,
    bool? mergeGroups,
  }) {
    return SemesterNasabAssignment(
      collegeName: collegeName,
      term: term,
      courseKey: courseKey,
      courseNameAr: courseNameAr,
      codeLocal: codeLocal,
      coverageScope: coverageScope,
      theoryTeacherId: theoryTeacherId == _keepValue
          ? this.theoryTeacherId
          : theoryTeacherId as String?,
      theoryTeacherName: theoryTeacherName ?? this.theoryTeacherName,
      practicalTeacherId: practicalTeacherId == _keepValue
          ? this.practicalTeacherId
          : practicalTeacherId as String?,
      practicalTeacherName: practicalTeacherName ?? this.practicalTeacherName,
      mergeGroups: mergeGroups ?? this.mergeGroups,
    );
  }
}
