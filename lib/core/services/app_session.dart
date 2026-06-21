import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';

/// خدمة الجلسة المركزية - تحتوي على بيانات المستخدم الحالي وصلاحياته
class AppSession {
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  String userId = '';
  String userName = '';
  String userEmail = '';
  String userRole = '';
  String userCollege = '';
  String userDepartment = '';

  /// تحميل بيانات الجلسة من SharedPreferences
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId') ?? '';
    userName = prefs.getString('userName') ?? '';
    userEmail = prefs.getString('userEmail') ?? '';
    userRole = prefs.getString('userRole') ?? '';
    userCollege = prefs.getString('college') ?? '';
    userDepartment = prefs.getString('userDepartment') ?? '';

    // إذا كان رئيس قسم ولم يتم تعيين القسم في الحساب، نقوم بجلبه من جدول الأقسام محلياً
    if (userDepartment.isEmpty && isDeptHead && userId.isNotEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final depts = await db.query(
          'departments',
          where: 'hod_id = ?',
          whereArgs: [userId],
          limit: 1,
        );
        if (depts.isNotEmpty) {
          userDepartment = depts.first['name']?.toString() ?? '';
          await prefs.setString('userDepartment', userDepartment);
        }
      } catch (e) {
        // نستخدم print بدلاً من debugPrint لعدم استيراد فلاتر هنا إذا لم تكن مستوردة
        print('Error loading department for HOD in AppSession: $e');
      }
    }
  }

  /// حفظ بيانات الجلسة
  Future<void> saveToPrefs({
    required String userId,
    required String userName,
    required String userEmail,
    required String userRole,
    required String userCollege,
    String userDepartment = '',
  }) async {
    this.userId = userId;
    this.userName = userName;
    this.userEmail = userEmail;
    this.userRole = userRole;
    this.userCollege = userCollege;
    this.userDepartment = userDepartment;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('userName', userName);
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('userRole', userRole);
    await prefs.setString('college', userCollege);
    await prefs.setString('userDepartment', userDepartment);
  }

  /// مسح بيانات الجلسة عند تسجيل الخروج
  Future<void> clear() async {
    userId = '';
    userName = '';
    userEmail = '';
    userRole = '';
    userCollege = '';
    userDepartment = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userRole');
    await prefs.remove('college');
    await prefs.remove('userDepartment');
    await prefs.remove('isLoggedIn');
  }

  // ====================== فحص الصلاحيات ======================

  /// تحويل النص المحفوظ إلى قائمة أدوار (لأنه قد يكون JSON Array)
  List<String> get _parsedRoles {
    if (userRole.isEmpty) return [];
    if (userRole.startsWith('[')) {
      try {
        final decoded = jsonDecode(userRole);
        return List<String>.from(decoded);
      } catch (e) {
        return [userRole];
      }
    }
    return [userRole];
  }

  bool _hasAnyRole(List<String> rolesToCheck) {
    final myRoles = _parsedRoles.map((r) => r.trim().toLowerCase()).toList();
    final checkList = rolesToCheck.map((r) => r.trim().toLowerCase()).toList();
    return myRoles.any((r) => checkList.contains(r));
  }

  /// مدير النظام أو النيابة العامة (يصل للواجهة الكاملة)
  bool get isAdminOrDeanship => _hasAnyRole([
        'admin',
        'super_admin',
        'super_admin4',
        'نيابة الشؤون الأكاديمية',
        'deanship',
        'Public Prosecution'
      ]);

  /// عميد الكلية
  bool get isDean => _hasAnyRole(['dean', 'عميد', 'Dean']);

  /// نائب العميد
  bool get isViceDean => _hasAnyRole([
        'vice_dean',
        'نائب العميد',
        'Vice Dean for Academic Affairs',
        'Vice Dean for Student Affairs'
      ]);

  /// رئيس قسم
  bool get isDeptHead =>
      _hasAnyRole(['dept_head', 'رئيس قسم', 'Head of department']);

  /// عضو هيئة تدريس
  bool get isMemberOnly =>
      _hasAnyRole(['member', 'faculty_member', 'Faculty Member']);

  /// أي دور له واجهة موبايل مع أزرار إضافية
  bool get hasMobileRoleWithExtras => isDean || isViceDean || isDeptHead;

  /// الاسم المعروض للدور (يُرجع أعلى منصب)
  String get roleDisplayName {
    if (isAdminOrDeanship) return 'مدير النظام / النيابة الأكاديمية';
    if (isDean) return 'عميد الكلية';
    if (isViceDean) return 'نائب العميد';
    if (isDeptHead) return 'رئيس القسم';
    if (isMemberOnly) return 'عضو هيئة تدريس';
    final roles = _parsedRoles;
    return roles.isNotEmpty ? roles.first : 'مستخدم';
  }

  /// قائمة **جميع** الأدوار الإضافية التي يملكها المستخدم
  /// (مفاتيح موحّدة: 'dean' | 'vice_dean' | 'dept_head')
  List<String> get extraRoleKeys {
    final roles = _parsedRoles.map((r) => r.trim().toLowerCase()).toList();
    final result = <String>[];
    if (roles.any((r) => ['dean', 'عميد', 'Dean'].map((e) => e.toLowerCase()).contains(r))) {
      result.add('dean');
    }
    if (roles.any((r) => [
          'vice_dean',
          'نائب العميد',
          'Vice Dean for Academic Affairs',
          'Vice Dean for Student Affairs',
          'vice dean for academic affairs',
          'vice dean for student affairs',
        ].map((e) => e.toLowerCase()).contains(r))) {
      result.add('vice_dean');
    }
    if (roles.any((r) => [
          'dept_head',
          'رئيس قسم',
          'Head of department',
          'head of department',
        ].map((e) => e.toLowerCase()).contains(r))) {
      result.add('dept_head');
    }
    return result;
  }

  /// تحويل مفتاح الدور الموحّد إلى اسم معروض
  String roleKeyToLabel(String roleKey) {
    switch (roleKey) {
      case 'dean':
        return 'مهام العميد';
      case 'vice_dean':
        return 'مهام نائب العميد';
      case 'dept_head':
        return 'مهام رئيس القسم';
      default:
        return 'المهام الإدارية';
    }
  }

  /// أيقونة الدور الموحّد
  String roleKeyToIcon(String roleKey) {
    switch (roleKey) {
      case 'dean':
        return 'account_balance';
      case 'vice_dean':
        return 'school';
      case 'dept_head':
        return 'account_tree';
      default:
        return 'admin_panel_settings';
    }
  }

  /// زر المهام الأول للتوافق مع الكود القديم
  String get roleTaskButtonLabel {
    final keys = extraRoleKeys;
    return keys.isNotEmpty ? roleKeyToLabel(keys.first) : '';
  }
}
