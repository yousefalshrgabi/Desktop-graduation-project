import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

class DepartmentsManagementViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collegeName = AppSession().userCollege;
  String collegeId = '';

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _facultyMembers = [];
  final Map<String, String> _hodNames = {}; // تخزين أسماء الرؤساء
  bool _isLoading = true;

  List<Map<String, dynamic>> get departments => _departments;
  List<Map<String, dynamic>> get facultyMembers => _facultyMembers;
  Map<String, String> get hodNames => _hodNames;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    if (collegeName.isEmpty || collegeName == 'غير محدد') {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      final colSnap = await db.query(
        'colleges',
        where: 'ar_name = ?',
        whereArgs: [collegeName],
        limit: 1,
      );
      if (colSnap.isNotEmpty) {
        collegeId = colSnap.first['id'].toString();
      }

      if (collegeId.isNotEmpty) {
        _departments = await db.query(
          'departments',
          where: 'college_id = ?',
          whereArgs: [collegeId],
        );
      } else {
        _departments = [];
      }

      _facultyMembers = await db.rawQuery('''
        SELECT f.*, u.name as user_name 
        FROM faculty_members f 
        JOIN users u ON f.user_id = u.id 
        WHERE u.faculty = ?
      ''', [collegeName]);

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
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveDepartment({
    required String name,
    required String? selectedHodId,
    Map<String, dynamic>? deptToEdit,
  }) async {
    if (collegeId.isEmpty) return false;

    try {
      final db = await DatabaseHelper.instance.database;
      final isEditing = deptToEdit != null;

      if (isEditing) {
        final deptId = deptToEdit['id'].toString();
        final oldHodId = deptToEdit['hod_id']?.toString() ?? '';

        final updatedData = {
          'name': name.trim(),
          'hod_id': selectedHodId ?? '',
        };

        // تحديث محلي
        await db.update('departments', updatedData, where: 'id = ?', whereArgs: [deptId]);
        // تحديث سحابي
        await _firestore.collection('departments').doc(deptId).update(updatedData);

        // تحديث الصلاحيات إذا تغير الرئيس
        if (oldHodId != selectedHodId) {
          if (oldHodId.isNotEmpty) {
            await _removeHodRole(oldHodId);
          }
          if (selectedHodId != null && selectedHodId.isNotEmpty) {
            await _assignHodRole(selectedHodId);
          }
        }
      } else {
        final newDeptRef = _firestore.collection('departments').doc();
        final newDeptId = newDeptRef.id;

        final deptData = {
          'id': newDeptId,
          'name': name.trim(),
          'college_id': collegeId,
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

        if (selectedHodId != null && selectedHodId.isNotEmpty) {
          await _assignHodRole(selectedHodId);
        }
      }

      await loadData();
      return true;
    } catch (e) {
      debugPrint('Error saving department: $e');
      return false;
    }
  }

  Future<bool> deleteDepartment(Map<String, dynamic> doc) async {
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
      await db.insert('deleted_records', {'id': deptId, 'table_name': 'departments'});

      // حذف سحابي
      await _firestore.collection('departments').doc(deptId).delete();

      await loadData();
      return true;
    } catch (e) {
      debugPrint('Error deleting department: $e');
      return false;
    }
  }

  Future<void> _assignHodRole(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userSnap = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);

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

          await db.update('users', {'role': newRole}, where: 'id = ?', whereArgs: [userId]);
          await _firestore.collection('users').doc(userId).update({'role': newRole});
        }
      }
    } catch (e) {
      debugPrint('Error assigning HOD role: $e');
    }
  }

  Future<void> _removeHodRole(String userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userSnap = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);

      if (userSnap.isNotEmpty) {
        String currentRole = userSnap.first['role']?.toString() ?? '';
        if (currentRole.contains('dept_head')) {
          String newRole = currentRole
              .replaceAll('"dept_head"', '')
              .replaceAll(', ,', ',')
              .replaceAll('[,', '[')
              .replaceAll(',]', ']');
          if (newRole == '[]') newRole = 'faculty_member'; // دور افتراضي

          await db.update('users', {'role': newRole}, where: 'id = ?', whereArgs: [userId]);
          await _firestore.collection('users').doc(userId).update({'role': newRole});
        }
      }
    } catch (e) {
      debugPrint('Error removing HOD role: $e');
    }
  }
}
