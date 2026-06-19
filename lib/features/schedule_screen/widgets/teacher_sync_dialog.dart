import 'package:flutter/material.dart';
import '../../desktop_pages/workload_management/models/faculty_option.dart';
import '../models/teacher_alias.dart';
import '../services/teacher_alias_service.dart';
import '../services/timetable_firestore_service.dart';

class TeacherSyncDialog extends StatefulWidget {
  final String collegeName;
  final List<String> unmappedNames;
  final List<FacultyOption> facultyMembers;
  final Function() onSyncComplete;

  const TeacherSyncDialog({
    super.key,
    required this.collegeName,
    required this.unmappedNames,
    required this.facultyMembers,
    required this.onSyncComplete,
  });

  @override
  State<TeacherSyncDialog> createState() => _TeacherSyncDialogState();
}

class _TeacherSyncDialogState extends State<TeacherSyncDialog> {
  final _aliasService = TeacherAliasService();
  final _timetableService = TimetableFirestoreService();
  final Map<String, String?> _selectedMappings = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var name in widget.unmappedNames) {
      _selectedMappings[name] = null;
    }
  }

  Future<void> _saveMappings() async {
    setState(() => _isSaving = true);
    try {
      for (final entry in _selectedMappings.entries) {
        final aliasName = entry.key;
        final canonicalName = entry.value;

        if (canonicalName != null && canonicalName.isNotEmpty) {
          final alias = TeacherAlias(
            id: '',
            collegeName: widget.collegeName,
            canonicalName: canonicalName,
            aliasName: aliasName,
          );
          await _aliasService.saveAlias(alias);
          
          // استبدال الاسم بشكل جذري داخل المحاضرات
          await _timetableService.replaceTeacherNameInActivities(
              widget.collegeName, aliasName, canonicalName);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المزامنة بنجاح')),
        );
        widget.onSyncComplete();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unmappedNames.isEmpty) {
      return AlertDialog(
        title: const Text('مزامنة المعلمين'),
        content: const Text('جميع المعلمين في الجدول مسجلون في قاعدة البيانات ولا توجد أسماء غير متعرف عليها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('مزامنة المعلمين (ربط الأسماء)'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الأسماء التالية تم استيرادها من الجدول الدراسي (FET) ولم يتم العثور عليها بشكل مطابق في قاعدة بيانات الكلية. يرجى اختيار المعلم الصحيح من القائمة لربط الأسماء ببعضها لضمان حساب النصاب بدقة.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: widget.unmappedNames.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final unmapped = widget.unmappedNames[index];
                  return Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          unmapped,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_outlined, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final selected = await showDialog<String?>(
                              context: context,
                              builder: (context) => _SearchableListDialog(
                                facultyMembers: widget.facultyMembers,
                                unmappedName: unmapped,
                              ),
                            );
                            if (selected != null) {
                              setState(() {
                                // We use a special marker to indicate "ignore"
                                _selectedMappings[unmapped] = selected == '__IGNORE__' ? null : selected;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedMappings[unmapped] == null
                                        ? 'بدون ربط (تجاهل)'
                                        : _getLabel(_selectedMappings[unmapped]!),
                                    style: TextStyle(
                                      color: _selectedMappings[unmapped] == null ? Colors.grey : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveMappings,
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('حفظ التغييرات'),
        ),
      ],
    );
  }

  String _getLabel(String name) {
    for (var f in widget.facultyMembers) {
      if (f.name == name) {
        return f.college.isNotEmpty ? '${f.name} (${f.college})' : f.name;
      }
    }
    return name;
  }
}

class _SearchableListDialog extends StatefulWidget {
  final List<FacultyOption> facultyMembers;
  final String unmappedName;

  const _SearchableListDialog({
    required this.facultyMembers,
    required this.unmappedName,
  });

  @override
  State<_SearchableListDialog> createState() => _SearchableListDialogState();
}

class _SearchableListDialogState extends State<_SearchableListDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FacultyOption> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.facultyMembers;
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = widget.facultyMembers);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = widget.facultyMembers.where((f) {
        return f.name.toLowerCase().contains(q) || f.college.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ربط: ${widget.unmappedName}'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'بحث بالاسم أو الكلية...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('بدون ربط (تجاهل)', style: TextStyle(color: Colors.grey)),
                    onTap: () => Navigator.of(context).pop('__IGNORE__'),
                  ),
                  const Divider(),
                  ..._filtered.map((f) {
                    final label = f.college.isNotEmpty ? '${f.name} (${f.college})' : f.name;
                    return ListTile(
                      title: Text(label),
                      onTap: () => Navigator.of(context).pop(f.name),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
