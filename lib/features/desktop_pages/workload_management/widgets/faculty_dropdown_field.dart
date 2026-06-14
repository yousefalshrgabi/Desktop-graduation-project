import 'package:flutter/material.dart';

import '../models/faculty_option.dart';

/// Dropdown for selecting a faculty member by document id.
class FacultyDropdownField extends StatelessWidget {
  const FacultyDropdownField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<FacultyOption> options;
  final String? selectedId;
  final void Function(FacultyOption?) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final validId =
        selectedId != null && options.any((option) => option.id == selectedId)
            ? selectedId
            : null;

    return DropdownButtonFormField<String>(
      initialValue: validId,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: '', child: Text('- لا يوجد -')),
        ...options.map(
          (faculty) => DropdownMenuItem(
            value: faculty.id,
            child: Text(
              faculty.department.isEmpty
                  ? faculty.name
                  : '${faculty.name} - ${faculty.department}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: !enabled
          ? null
          : (id) {
              if (id == null || id.isEmpty) {
                onChanged(null);
                return;
              }
              onChanged(options.firstWhere((faculty) => faculty.id == id));
            },
    );
  }
}
