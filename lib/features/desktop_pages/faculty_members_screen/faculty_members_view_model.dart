import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'faculty_member_model.dart';

class FacultyMembersViewModel extends ChangeNotifier {
  List<FacultyMemberModel> allMembers = [];
  bool isLoading = false;
  String errorMessage = '';

  FacultyMembersViewModel() {
    fetchFacultyMembers();
  }

  // ==================== 1. جلب البيانات ====================
  Future<void> fetchFacultyMembers() async {
    isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('faculty_members');
      allMembers =
          result.map((doc) => FacultyMemberModel.fromMap(doc)).toList();
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error fetching faculty members: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 2. معالجة ورفع الملفات المرفقة ====================
  // ==================== معالجة ورفع الملفات بتنظيم المجلدات (إسم العضو) ====================
  Future<FacultyMemberModel> _processAndUploadFile(
      FacultyMemberModel member) async {
    // إذا لم يكن هناك ملف محلي جديد تم اختياره، نرجع المودل كما هو
    if (member.localFilePath.isEmpty ||
        !File(member.localFilePath).existsSync()) {
      return member;
    }

    try {
      File sourceFile = File(member.localFilePath);
      String extension = p.extension(sourceFile.path);
      // تنظيف اسم العضو من أي رموز قد لا يقبلها نظام الملفات (مثل / أو \)
      String cleanName = member.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String fileName = 'document$extension';

      // --- 1. التنظيم المحلي: Documents/AcademicAffairs/FacultyFiles/اسم_العضو/الملف ---
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String memberDirPath =
          p.join(appDocDir.path, 'AcademicAffairs', 'FacultyFiles', cleanName);
      Directory memberDir = Directory(memberDirPath);

      // إنشاء مجلد العضو إذا لم يكن موجوداً
      if (!await memberDir.exists()) {
        await memberDir.create(recursive: true);
      }

      String newLocalPath = p.join(memberDir.path, fileName);
      await sourceFile.copy(newLocalPath);
      debugPrint('✅ تم حفظ الملف محلياً في مجلد العضو: $newLocalPath');

      // --- 2. التنظيم السحابي: faculty_files/اسم_العضو/الملف ---
      String downloadUrl = member.fileUrl;
      try {
        debugPrint('☁️ جاري رفع الملف إلى Firebase Storage بتنظيم المجلدات...');
        // إنشاء مرجع في الفايربيز: faculty_files -> اسم العضو -> الملف
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('faculty_files/$cleanName/$fileName');

        UploadTask uploadTask = ref.putFile(File(newLocalPath));
        TaskSnapshot snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('✅ تم الرفع للسحابة بنجاح: $downloadUrl');
      } catch (firebaseError) {
        debugPrint('⚠️ فشل الرفع السحابي: $firebaseError');
      }

      // إرجاع المودل المحدث بالمسارات الجديدة
      return member.copyWith(
        localFilePath: newLocalPath,
        fileUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('❌ خطأ أثناء تنظيم وحفظ الملف: $e');
      return member;
    }
  }

  // ==================== 3. إضافة عضو ====================
  Future<void> addFacultyMember(FacultyMemberModel member) async {
    isLoading = true;
    notifyListeners();
    try {
      // 👈 نعالج الملف (حفظ محلي + رفع سحابي) قبل إدخال البيانات للقاعدة
      FacultyMemberModel finalMember = await _processAndUploadFile(member);

      final db = await DatabaseHelper.instance.database;
      await db.insert('faculty_members', finalMember.toMap());
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error adding member: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 4. تعديل عضو ====================
  Future<void> updateFacultyMember(String id, FacultyMemberModel member) async {
    isLoading = true;
    notifyListeners();
    try {
      // 👈 نعالج الملف (حفظ محلي + رفع سحابي) قبل التحديث
      FacultyMemberModel finalMember = await _processAndUploadFile(member);

      final db = await DatabaseHelper.instance.database;
      await db.update('faculty_members', finalMember.toMap(),
          where: 'id = ?', whereArgs: [id]);

      // تحديث اسم المستخدم المرتبط إذا تم تغييره من هنا
      if (finalMember.userId.isNotEmpty) {
        await db.update('users', {'name': finalMember.name},
            where: 'id = ?', whereArgs: [finalMember.userId]);
      }

      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error updating member: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 5. حذف عضو ====================
  Future<void> deleteFacultyMember(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('faculty_members', where: 'id = ?', whereArgs: [id]);
        await txn.insert(
            'deleted_records', {'id': id, 'table_name': 'faculty_members'});
      });
      await fetchFacultyMembers();
    } catch (e) {
      debugPrint('Error deleting member: $e');
      rethrow;
    }
  }

  // ==================== 6. الاستيراد الذكي من الإكسل ====================
  Future<void> importFacultyMembersFromExcel(BuildContext context) async {
    try {
      debugPrint('[IMPORT DEBUG] 🟢 بدء عملية الاستيراد الذكية...');

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      isLoading = true;
      notifyListeners();

      List<int> bytes;
      if (result.files.single.bytes != null) {
        bytes = result.files.single.bytes!;
      } else if (result.files.single.path != null) {
        bytes = File(result.files.single.path!).readAsBytesSync();
      } else {
        throw Exception('تعذر الوصول إلى بيانات الملف.');
      }

      var decoder = SpreadsheetDecoder.decodeBytes(bytes);
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        for (String sheetName in decoder.tables.keys) {
          if (sheetName.startsWith('ورقة') ||
              sheetName.toLowerCase().startsWith('sheet')) continue;

          var sheet = decoder.tables[sheetName];
          if (sheet == null || sheet.rows.length <= 3) continue;

          String collegeName = sheetName.trim();

          List<Map<String, dynamic>> existingColleges = await txn.query(
              'colleges',
              where: 'ar_name = ?',
              whereArgs: [collegeName]);
          if (existingColleges.isEmpty) {
            String newCollegeId =
                DateTime.now().millisecondsSinceEpoch.toString() + 'C';
            await txn.insert('colleges', {
              'id': newCollegeId,
              'ar_name': collegeName,
              'en_name': '',
              'code': '',
              'dean_id': '',
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          for (int i = 3; i < sheet.rows.length; i++) {
            var row = sheet.rows[i];
            if (row.isEmpty) continue;

            String clean(int index) {
              if (index >= row.length) return '';
              var cell = row[index];
              if (cell == null) return '';
              String val = cell.toString().trim();
              if (val == '_' ||
                  val == '-' ||
                  val.toLowerCase() == 'nan' ||
                  val.toLowerCase() == 'null') return '';
              return val;
            }

            final name = clean(1);
            if (name.isEmpty) continue;

            String dept = clean(33);
            if (dept.isEmpty) dept = 'غير محدد';

            // 1. معالجة وربط المستخدم
            List<Map<String, dynamic>> existingUsers =
                await txn.query('users', where: 'name = ?', whereArgs: [name]);
            String userId;
            if (existingUsers.isNotEmpty) {
              userId = existingUsers.first['id']?.toString() ?? '';
              if (userId.isNotEmpty) {
                await txn.update(
                    'users', {'faculty': collegeName, 'department': dept},
                    where: 'id = ?', whereArgs: [userId]);
              }
            } else {
              userId = DateTime.now().millisecondsSinceEpoch.toString() + 'U$i';
              await txn.insert('users', {
                'id': userId,
                'name': name,
                'email': '',
                'phone': '',
                'role': 'Faculty Member',
                'faculty': collegeName,
                'department': dept,
                'status': 'نشط',
                'created_at': DateTime.now().toIso8601String(),
              });
            }

            // 2. معالجة الإجازات والتفرغ
            List<Map<String, String>> sabbaticalList = [];
            void addSabbatical(int periodIdx, int dateIdx, int univIdx) {
              String period = clean(periodIdx);
              String date = clean(dateIdx);
              String univ = clean(univIdx);

              if (period.isNotEmpty || date.isNotEmpty || univ.isNotEmpty) {
                String start = date;
                String end = '';
                if (date.contains('-')) {
                  var parts = date.split('-');
                  start = parts[0].trim();
                  end = parts[1].trim();
                }
                String details =
                    [period, univ].where((e) => e.isNotEmpty).join(' - ');
                sabbaticalList
                    .add({'start': start, 'end': end, 'details': details});
              }
            }

            addSabbatical(36, 37, 38);
            addSabbatical(39, 40, 41);
            addSabbatical(42, 43, 44);

            List<Map<String, String>> unpaidList = [];
            void addUnpaid(int idx) {
              String val = clean(idx);
              if (val.isNotEmpty)
                unpaidList.add({'start': '', 'end': '', 'details': val});
            }

            addUnpaid(45);
            addUnpaid(46);
            addUnpaid(47);

            // 🌟 3. الفصل الذكي لتاريخ ومكان الميلاد
            String rawBirthData = clean(5);
            String birthPlace = '';
            String birthDate = '';

            if (rawBirthData.isNotEmpty) {
              int firstDigitIndex = rawBirthData.indexOf(RegExp(r'\d'));
              if (firstDigitIndex != -1) {
                birthPlace = rawBirthData.substring(0, firstDigitIndex).trim();
                if (birthPlace.endsWith('-') || birthPlace.endsWith('/')) {
                  birthPlace =
                      birthPlace.substring(0, birthPlace.length - 1).trim();
                }
                birthDate = rawBirthData.substring(firstDigitIndex).trim();
              } else {
                birthPlace = rawBirthData;
              }
            }

            // 4. تجهيز الحفظ
            Map<String, dynamic> facultyData = {
              'user_id': userId,
              'name': name,
              'file_number': clean(2),
              'id_card_number': clean(3),
              'job_number': clean(4),
              'birth_place': birthPlace, // 👈 مكان الميلاد مفصول
              'birth_date': birthDate, // 👈 تاريخ الميلاد مفصول
              'first_appointment_date': clean(6),
              'university_appointment_date': clean(7),

              'bsc_degree': clean(8),
              'bsc_date': clean(9),
              'bsc_university': clean(10),
              'bsc_country': clean(11),
              'bsc_academic_title': clean(12),
              'bsc_title_transfer_date': clean(13),
              'bsc_specialization': clean(14),

              'msc_degree': clean(15),
              'msc_date': clean(16),
              'msc_university': clean(17),
              'msc_country': clean(18),
              'msc_academic_title': clean(19),
              'msc_title_transfer_date': clean(20),
              'msc_decision_number': clean(21),
              'msc_exact_specialization': clean(22),

              'current_degree': clean(23),
              'current_degree_date': clean(24),
              'current_university': clean(25),
              'current_country': clean(26),

              'assistant_prof_date': clean(27),
              'assistant_prof_decision': clean(28),
              'assoc_prof_date': clean(29),
              'assoc_prof_decision': clean(30),

              'current_academic_title': clean(31),
              'title_transfer_date': clean(32),
              'department': dept,
              'general_specialization': clean(34),
              'exact_specialization': clean(35),

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
        }
      });

      await fetchFacultyMembers();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم استيراد وترتيب البيانات بنجاح!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ حدث خطأ فادح أثناء الاستيراد: $e\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
