import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'faculty_member_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

class FacultyMembersViewModel extends ChangeNotifier {
  List<FacultyMemberModel> allMembers = [];
  bool isLoading = true;
  String errorMessage = '';

  FacultyMembersViewModel() {
    fetchFacultyMembers();
  }

  Future<void> fetchFacultyMembers() async {
    isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result =
          await db.query('faculty_members');
      allMembers =
          result.map((map) => FacultyMemberModel.fromMap(map)).toList();
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error fetching faculty members: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  // دالة الإضافة (للأعضاء الذين يضافون من هذه الشاشة مباشرة)
  Future<void> addFacultyMember(FacultyMemberModel member) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('faculty_members', member.toMap());
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error adding faculty member: $e');
      rethrow;
    }
  }

  // دالة التعديل (وهي الأهم لاستكمال بيانات الأعضاء)
  Future<void> updateFacultyMember(
      String memberId, FacultyMemberModel updatedMember) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // نستخدم دالة toMap الجاهزة في المودل التي تحتوي على جميع الـ 30 حقل
      Map<String, dynamic> data = updatedMember.toMap();

      await db.update(
        'faculty_members',
        data,
        where: 'id = ?',
        whereArgs: [memberId],
      );

      await fetchFacultyMembers();
      debugPrint('تم تحديث الملف الأكاديمي الشامل بنجاح: $memberId');
    } catch (e) {
      debugPrint('Error updating faculty member: $e');
      rethrow;
    }
  }

  Future<void> deleteFacultyMember(String memberId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // 1. جلب الـ user_id المرتبط بهذا العضو قبل حذفه
        final List<Map<String, dynamic>> memberResult = await txn.query(
          'faculty_members',
          columns: ['user_id'],
          where: 'id = ?',
          whereArgs: [memberId],
        );

        if (memberResult.isNotEmpty) {
          final String? userId = memberResult.first['user_id'];

          // 2. حذف العضو من جدول أعضاء هيئة التدريس
          await txn.delete('faculty_members',
              where: 'id = ?', whereArgs: [memberId]);

          // تسجيل حذف العضو للمزامنة
          await txn.insert('deleted_records',
              {'id': memberId, 'table_name': 'faculty_members'});

          // 3. حذف المستخدم المرتبط (إذا وجد)
          if (userId != null && userId.isNotEmpty) {
            await txn.delete('users', where: 'id = ?', whereArgs: [userId]);

            // تسجيل حذف المستخدم للمزامنة مع Firebase
            await txn.insert(
                'deleted_records', {'id': userId, 'table_name': 'users'});
          }
        }
      });

      // تحديث القائمة في الواجهة
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error deleting faculty member and user: $e');
      rethrow;
    }
  }

  Future<void> importFacultyMembersFromExcel(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return;

      isLoading = true;
      notifyListeners();

      final file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      String sheetName = excel.tables.keys.first;
      Sheet sheet = excel.tables[sheetName]!;

      if (sheet.maxRows <= 2) {
        throw Exception('ملف الإكسل فارغ أو لا يحتوي على بيانات.');
      }

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        for (int i = 2; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.isEmpty) continue;

          String clean(int index) {
            if (index >= row.length ||
                row[index] == null ||
                row[index]?.value == null) {
              return '';
            }
            return row[index]!.value.toString().trim();
          }

          final name = clean(1);
          if (name.isEmpty) continue;

          final email = clean(7);
          final phone = clean(8);

          // 1. إدارة حساب المستخدم
          List<Map<String, dynamic>> existingUsers = [];
          if (email.isNotEmpty) {
            existingUsers = await txn
                .query('users', where: 'email = ?', whereArgs: [email]);
          }

          String userId;
          if (existingUsers.isNotEmpty) {
            userId = existingUsers.first['id'] as String;
            await txn.update(
                'users',
                {
                  'name': name,
                  'phone': phone,
                },
                where: 'id = ?',
                whereArgs: [userId]);
          } else {
            userId = DateTime.now().millisecondsSinceEpoch.toString() + 'U$i';
            await txn.insert('users', {
              'id': userId,
              'name': name, 
              'email': email,
              'phone': phone,
              'role': 'Faculty Member',
              'status': 'نشط',
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // 2. معالجة الإجازات والتفرغ (37-48)
          List<Map<String, String>> sabbaticalList = [];
          if (clean(37).isNotEmpty ||
              clean(38).isNotEmpty ||
              clean(39).isNotEmpty) {
            sabbaticalList.add(
                {'start': clean(38), 'end': clean(37), 'details': clean(39)});
          }
          if (clean(40).isNotEmpty ||
              clean(41).isNotEmpty ||
              clean(42).isNotEmpty) {
            sabbaticalList.add(
                {'start': clean(41), 'end': clean(40), 'details': clean(42)});
          }
          if (clean(43).isNotEmpty ||
              clean(44).isNotEmpty ||
              clean(45).isNotEmpty) {
            sabbaticalList.add(
                {'start': clean(44), 'end': clean(43), 'details': clean(45)});
          }

          List<Map<String, String>> unpaidList = [];
          if (clean(46).isNotEmpty)
            unpaidList.add({'start': '-', 'end': '-', 'details': clean(46)});
          if (clean(47).isNotEmpty)
            unpaidList.add({'start': '-', 'end': '-', 'details': clean(47)});
          if (clean(48).isNotEmpty)
            unpaidList.add({'start': '-', 'end': '-', 'details': clean(48)});

          // 3. تجهيز البيانات الأكاديمية بناءً على الترقيم الدقيق
          Map<String, dynamic> facultyData = {
            'user_id': userId,
            'name': name,
            'email': email,
            'file_number': clean(2),
            'id_card_number': clean(3),
            'job_number': clean(4),
            'birth_place': clean(5),
            'first_appointment_date': clean(6),

            // بكالوريوس (9-15)
            'bsc_degree': clean(9),
            'bsc_date': clean(10),
            'bsc_university': clean(11),
            'bsc_country': clean(12),
            'bsc_academic_title': clean(13),
            'bsc_title_transfer_date': clean(14),
            'bsc_specialization': clean(15),

            // ماجستير (16-23) - تم التعديل هنا بدقة
            'msc_degree': clean(16),
            'msc_date': clean(17),
            'msc_university': clean(18),
            'msc_country': clean(19),
            'msc_academic_title': clean(20),
            'msc_title_transfer_date': clean(21),
            'msc_decision_number': clean(22), // 👈 الخلية 22 كما طلبت
            'msc_exact_specialization': clean(23), // 👈 الخلية 23 كما طلبت

            // دكتوراه (24-27)
            'current_degree': clean(24),
            'current_degree_date': clean(25),
            'current_university': clean(26),
            'current_country': clean(27),

            // الترقيات (28-31)
            'assistant_prof_date': clean(28),
            'assistant_prof_decision': clean(29), // 👈 الخلية 29 هي القرار نفسه
            'assoc_prof_decision': clean(30),
            'assoc_prof_date': clean(31),

            // البيانات الحالية (32-36)
            'current_academic_title': clean(32),
            'title_transfer_date': clean(33),
            'department': clean(34),
            'general_specialization': clean(35),
            'exact_specialization': clean(36),

            'sabbatical_leaves': jsonEncode(sabbaticalList),
            'unpaid_leaves': jsonEncode(unpaidList),
            'status': 'نشط',
          };

          final existingFaculty = await txn.query('faculty_members',
              where: 'user_id = ?', whereArgs: [userId]);

          if (existingFaculty.isNotEmpty) {
            final facultyId = existingFaculty.first['id'] as String;
            await txn.update('faculty_members', facultyData,
                where: 'id = ?', whereArgs: [facultyId]);
          } else {
            facultyData['id'] =
                DateTime.now().millisecondsSinceEpoch.toString() + 'F$i';
            facultyData['created_at'] = DateTime.now().toIso8601String();
            await txn.insert('faculty_members', facultyData);
          }
        }
      });

      await fetchFacultyMembers();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('تم استيراد كافة بيانات الماجستير والترقيات بنجاح!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Import Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ في القراءة: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
