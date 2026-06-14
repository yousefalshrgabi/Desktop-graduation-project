/// Lightweight faculty row for assignment dropdowns.
class FacultyOption {
  const FacultyOption({
    required this.id,
    required this.name,
    required this.college,
    this.department = '',
  });

  final String id;
  final String name;
  final String college;
  final String department;

  static const FacultyOption empty = FacultyOption(
    id: '',
    name: '',
    college: '',
    department: '',
  );

  factory FacultyOption.fromFirestore(String id, Map<String, dynamic> data) {
    // دعم كلا الهيكلين: هيكل maz (المتداخل) وهيكل النظام الحالي (المسطح)
    final personal = (data['personal_info'] as Map?)?.cast<String, dynamic>() ?? {};
    final dept = (data['academic_department'] as Map?)?.cast<String, dynamic>() ?? {};

    return FacultyOption(
      id: id,
      name: (data['name'] ?? personal['name'] ?? '').toString().trim(),
      college: (data['college'] ?? dept['college'] ?? '').toString().trim(),
      department: (data['department'] ?? dept['department'] ?? '').toString().trim(),
    );
  }

  String get shortName {
    final parts = name.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0];
    return parts.map((part) => part.isNotEmpty ? part[0] : '').join('.');
  }
}
