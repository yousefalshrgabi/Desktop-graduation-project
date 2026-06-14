class TeacherAlias {
  final String id; // Usually the doc ID
  final String collegeName;
  final String canonicalName; // The official name in faculty_members
  final String aliasName; // The name from the FET schedule

  TeacherAlias({
    required this.id,
    required this.collegeName,
    required this.canonicalName,
    required this.aliasName,
  });

  factory TeacherAlias.fromMap(String id, Map<String, dynamic> data) {
    return TeacherAlias(
      id: id,
      collegeName: (data['college_name'] ?? '').toString().trim(),
      canonicalName: (data['canonical_name'] ?? '').toString().trim(),
      aliasName: (data['alias_name'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'college_name': collegeName,
      'canonical_name': canonicalName,
      'alias_name': aliasName,
    };
  }
}
