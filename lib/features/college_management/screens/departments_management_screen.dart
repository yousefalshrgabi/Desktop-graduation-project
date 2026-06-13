import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DepartmentsManagementScreen extends StatefulWidget {
  const DepartmentsManagementScreen({super.key});

  @override
  State<DepartmentsManagementScreen> createState() =>
      _DepartmentsManagementScreenState();
}

class _DepartmentsManagementScreenState
    extends State<DepartmentsManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String _collegeName;
  String _collegeId = '';

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _facultyMembers = [];
  final Map<String, String> _hodNames = {}; // تخزين أسماء الرؤساء
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _collegeName = AppSession().userCollege;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      final colSnap = await db.query(
        'colleges',
        where: 'ar_name = ?',
        whereArgs: [_collegeName],
        limit: 1,
      );
      if (colSnap.isNotEmpty) {
        _collegeId = colSnap.first['id'].toString();
      }

      if (_collegeId.isNotEmpty) {
        _departments = await db.query(
          'departments',
          where: 'college_id = ?',
          whereArgs: [_collegeId],
        );
      } else {
        _departments = [];
      }

      _facultyMembers = await db.rawQuery('''
        SELECT f.*, u.name as user_name 
        FROM faculty_members f 
        JOIN users u ON f.user_id = u.id 
        WHERE u.faculty = ?
      ''', [_collegeName]);

      // مطابقة 100% مع الديسكتوب: جلب اسم رئيس القسم مباشرة من جدول المستخدمين
      _hodNames.clear();
      for (var dept in _departments) {
        String hodId = dept['hod_id']?.toString() ?? '';
        if (hodId.isNotEmpty && !_hodNames.containsKey(hodId)) {
          final uSnap = await db.query('users',
              where: 'id = ?', whereArgs: [hodId], limit: 1);
          if (uSnap.isNotEmpty) {
            _hodNames[hodId] = uSnap.first['name']?.toString() ?? 'غير محدد';
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDepartmentDialog({Map<String, dynamic>? deptToEdit}) async {
    if (_collegeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'تعذر العثور على الكلية في قاعدة البيانات المحلية. يرجى المزامنة.')),
      );
      return;
    }

    final isEditing = deptToEdit != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? deptToEdit['name'] : '');
    String? selectedHodId =
        isEditing && deptToEdit['hod_id'].toString().isNotEmpty
            ? deptToEdit['hod_id'].toString()
            : null;

    // تأمين عدم تكرار العناصر وتأمين وجود القيمة المحددة لمنع خطأ DropdownButton
    final uniqueFaculty = <String, Map<String, dynamic>>{};
    for (var f in _facultyMembers) {
      final uid = f['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) uniqueFaculty[uid] = f;
    }

    // إذا كان رئيس القسم الحالي غير موجود في قائمة دكاترة الكلية (مثلاً تم تعيينه من الديسكتوب من كلية أخرى)
    // نقوم بإضافته مؤقتاً للقائمة المنسدلة لكي لا ينهار التطبيق
    if (selectedHodId != null && !uniqueFaculty.containsKey(selectedHodId)) {
      uniqueFaculty[selectedHodId] = {
        'user_id': selectedHodId,
        'name': _hodNames[selectedHodId] ?? 'مستخدم من خارج الكلية',
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
                              child: Text(fac['user_name']?.toString() ??
                                  fac['name']?.toString() ??
                                  'غير محدد'),
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
      try {
        final db = await DatabaseHelper.instance.database;

        if (isEditing) {
          final deptId = deptToEdit['id'].toString();
          final oldHodId = deptToEdit['hod_id']?.toString() ?? '';

          final updatedData = {
            'name': nameCtrl.text.trim(),
            'hod_id': selectedHodId ?? '',
          };

          // تحديث محلي
          await db.update('departments', updatedData,
              where: 'id = ?', whereArgs: [deptId]);
          // تحديث سحابي
          await _firestore
              .collection('departments')
              .doc(deptId)
              .update(updatedData);

          // تحديث الصلاحيات إذا تغير الرئيس
          if (oldHodId != selectedHodId) {
            if (oldHodId.isNotEmpty) {
              await _removeHodRole(oldHodId);
            }
            if (selectedHodId != null && selectedHodId!.isNotEmpty) {
              await _assignHodRole(selectedHodId!);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تعديل القسم بنجاح')),
            );
          }
        } else {
          final newDeptRef = _firestore.collection('departments').doc();
          final newDeptId = newDeptRef.id;

          final deptData = {
            'id': newDeptId,
            'name': nameCtrl.text.trim(),
            'college_id': _collegeId,
            'hod_id': selectedHodId ?? '',
            'created_at': DateTime.now().toIso8601String(),
          };

          // حفظ محلي
          await db.insert('departments', deptData);
          // حفظ سحابي
          await newDeptRef.set({
            ...deptData,
            'created_at': FieldValue.serverTimestamp(),
          });

          if (selectedHodId != null && selectedHodId!.isNotEmpty) {
            await _assignHodRole(selectedHodId!);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمت إضافة القسم بنجاح')),
            );
          }
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
          );
        }
      }
    }
  }

  Future<void> _assignHodRole(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userSnap = await db.query('users',
          where: 'id = ?', whereArgs: [userId], limit: 1);

      if (userSnap.isNotEmpty) {
        String currentRole = userSnap.first['role']?.toString() ?? '';
        if (!currentRole.contains('dept_head') &&
            !currentRole.contains('رئيس قسم') &&
            !currentRole.contains('Head of department')) {
          String newRole = currentRole;
          if (newRole.isEmpty) {
            newRole = 'dept_head';
          } else if (!newRole.startsWith('[')) {
            newRole = '["$newRole", "dept_head"]';
          } else {
            newRole = newRole.replaceFirst(']', ', "dept_head"]');
          }

          await db.update('users', {'role': newRole},
              where: 'id = ?', whereArgs: [userId]);
          await _firestore
              .collection('users')
              .doc(userId)
              .update({'role': newRole});
        }
      }
    } catch (e) {
      debugPrint('Error assigning HOD role: $e');
    }
  }

  Future<void> _removeHodRole(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userSnap = await db.query('users',
          where: 'id = ?', whereArgs: [userId], limit: 1);

      if (userSnap.isNotEmpty) {
        String currentRole = userSnap.first['role']?.toString() ?? '';
        if (currentRole.contains('dept_head')) {
          String newRole = currentRole
              .replaceAll('"dept_head"', '')
              .replaceAll(', ,', ',')
              .replaceAll('[,', '[')
              .replaceAll(',]', ']');
          if (newRole == '[]') newRole = 'faculty_member'; // دور افتراضي

          await db.update('users', {'role': newRole},
              where: 'id = ?', whereArgs: [userId]);
          await _firestore
              .collection('users')
              .doc(userId)
              .update({'role': newRole});
        }
      }
    } catch (e) {
      debugPrint('Error removing HOD role: $e');
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
      try {
        final deptId = doc['id'].toString();
        final hodId = doc['hod_id']?.toString() ?? '';
        final db = await DatabaseHelper.instance.database;

        // إزالة صلاحية رئيس القسم
        if (hodId.isNotEmpty) {
          await _removeHodRole(hodId);
        }

        // حذف محلي
        await db.delete('departments', where: 'id = ?', whereArgs: [deptId]);
        await db.insert(
            'deleted_records', {'id': deptId, 'table_name': 'departments'});

        // حذف سحابي
        await _firestore.collection('departments').doc(deptId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف القسم بنجاح')),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_collegeName.isEmpty || _collegeName == 'غير محدد') {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة الأقسام العلمية')),
        body: const Center(
          child: Text('عذراً، لم يتم تحديد كلية لحسابك.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة أقسام: $_collegeName'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDepartmentDialog(),
        tooltip: 'إضافة قسم',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? const Center(child: Text('لا توجد أقسام مسجلة في هذه الكلية.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _departments.length,
                  itemBuilder: (context, index) {
                    final doc = _departments[index];
                    final name = doc['name'] ?? 'بدون اسم';
                    final hodId = doc['hod_id']?.toString() ?? '';

                    String hodName = 'غير محدد';
                    if (hodId.isNotEmpty) {
                      hodName = _hodNames[hodId] ?? 'غير محدد';
                    }

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
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
                              icon: const Icon(Icons.edit_rounded,
                                  color: Colors.blue),
                              onPressed: () =>
                                  _showDepartmentDialog(deptToEdit: doc),
                              tooltip: 'تعديل القسم',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded,
                                  color: Colors.red),
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
  }
}
