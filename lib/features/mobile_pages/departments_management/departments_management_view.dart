import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'departments_management_view_model.dart';

class DepartmentsManagementView extends StatefulWidget {
  const DepartmentsManagementView({super.key});

  @override
  State<DepartmentsManagementView> createState() => _DepartmentsManagementViewState();
}

class _DepartmentsManagementViewState extends State<DepartmentsManagementView> {
  late final DepartmentsManagementViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = DepartmentsManagementViewModel();
    _viewModel.loadData();
  }

  Future<void> _showDepartmentDialog({Map<String, dynamic>? deptToEdit}) async {
    if (_viewModel.collegeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر العثور على الكلية في قاعدة البيانات المحلية. يرجى المزامنة.')),
      );
      return;
    }

    final isEditing = deptToEdit != null;
    final nameCtrl = TextEditingController(text: isEditing ? deptToEdit['name'] : '');
    String? selectedHodId = isEditing && deptToEdit['hod_id'].toString().isNotEmpty
        ? deptToEdit['hod_id'].toString()
        : null;

    final uniqueFaculty = <String, Map<String, dynamic>>{};
    for (var f in _viewModel.facultyMembers) {
      final uid = f['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) uniqueFaculty[uid] = f;
    }

    if (selectedHodId != null && !uniqueFaculty.containsKey(selectedHodId)) {
      uniqueFaculty[selectedHodId] = {
        'user_id': selectedHodId,
        'name': _viewModel.hodNames[selectedHodId] ?? 'مستخدم من خارج الكلية',
      };
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل القسم' : 'إضافة قسم جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم القسم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'رئيس القسم (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedHodId,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('بدون تحديد'),
                          ),
                          ...uniqueFaculty.values.map((fac) {
                            return DropdownMenuItem<String>(
                              value: fac['user_id'].toString(),
                              child: Text(fac['user_name']?.toString() ?? fac['name']?.toString() ?? 'غير محدد'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedHodId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال اسم القسم')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(isEditing ? 'حفظ' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final success = await _viewModel.saveDepartment(
        name: nameCtrl.text,
        selectedHodId: selectedHodId,
        deptToEdit: deptToEdit,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEditing ? 'تم تعديل القسم بنجاح' : 'تمت إضافة القسم بنجاح')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ أثناء حفظ القسم')),
          );
        }
      }
    }
  }

  Future<void> _deleteDepartment(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القسم'),
        content: Text('هل أنت متأكد من حذف قسم "${doc['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _viewModel.deleteDepartment(doc);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف القسم بنجاح')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ أثناء حذف القسم')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DepartmentsManagementViewModel>.value(
      value: _viewModel,
      child: Consumer<DepartmentsManagementViewModel>(
        builder: (context, viewModel, child) {
          final collegeName = viewModel.collegeName;

          if (collegeName.isEmpty || collegeName == 'غير محدد') {
            return Scaffold(
              appBar: AppBar(title: const Text('إدارة الأقسام العلمية')),
              body: const Center(
                child: Text('عذراً، لم يتم تحديد كلية لحسابك.'),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('إدارة أقسام: $collegeName'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: viewModel.loadData,
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showDepartmentDialog(),
              tooltip: 'إضافة قسم',
              child: const Icon(Icons.add),
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.departments.isEmpty
                    ? const Center(child: Text('لا توجد أقسام مسجلة في هذه الكلية.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.departments.length,
                        itemBuilder: (context, index) {
                          final doc = viewModel.departments[index];
                          final name = doc['name'] ?? 'بدون اسم';
                          final hodId = doc['hod_id']?.toString() ?? '';

                          String hodName = 'غير محدد';
                          if (hodId.isNotEmpty) {
                            hodName = viewModel.hodNames[hodId] ?? 'غير محدد';
                          }

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: const Icon(Icons.account_tree_rounded),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('رئيس القسم: $hodName'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                    onPressed: () => _showDepartmentDialog(deptToEdit: doc),
                                    tooltip: 'تعديل القسم',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                    onPressed: () => _deleteDepartment(doc),
                                    tooltip: 'حذف القسم',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          );
        },
      ),
    );
  }
}
