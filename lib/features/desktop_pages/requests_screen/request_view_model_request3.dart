import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:file_saver/file_saver.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/utils/app_file_saver.dart';
import 'package:academic_affairs_management/core/services/docx_export_service.dart';
import 'package:uuid/uuid.dart';
import 'request_model.dart';

class RequestViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<RequestModel> _receivedRequests = [];
  List<RequestModel> _sentRequests = [];
  bool _isLoading = false;
  bool _isSending = false;
  String _errorMessage = '';

  List<RequestModel> get receivedRequests => _receivedRequests;
  List<RequestModel> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String get errorMessage => _errorMessage;

  String? _currentUserRole;
  String? _currentUserName;
  String? _currentUserCollege;
  String? _currentUserId; // 👈 معرف المستخدم الحالي
  String? _currentUserDepartment; // 👈 القسم الحالي للمستخدم
  String? get currentUserDepartment => _currentUserDepartment;

  List<String> _collegeDepartments = [];
  List<String> get collegeDepartments => _collegeDepartments;

  List<String> _colleges = [];
  List<String> get colleges => _colleges;

  StreamSubscription? _receivedSubscription;
  StreamSubscription? _sentSubscription;
  bool _isDisposed = false; // 👈 علم لتتبع حالة الكائن

  RequestViewModel() {
    _loadCurrentUser();
  }

  bool _isManualMode = false;

  // دالة مساعدة لتحويل التواريخ القادمة من فيربيس إلى نص ISO لـ SQLite
  String _formatDateForSqlite(dynamic date) {
    if (date == null) return DateTime.now().toIso8601String();
    if (date is Timestamp) return date.toDate().toIso8601String();
    if (date is DateTime) return date.toIso8601String();
    return date.toString();
  }

  void setUserData({
    required String name,
    required String college,
    required String role,
    String? userId,
    String? department,
  }) {
    _isManualMode = true;
    _currentUserName = name;
    _currentUserCollege = college;
    _currentUserRole = role;
    _currentUserId = userId;
    _currentUserDepartment = department;

    // إذا كان رئيس قسم والمسار فارغ، نتحقق من قاعدة البيانات المحلية (SQLite)
    final bool isHOD = (role).toLowerCase().contains('head') ||
                       (role).contains('رئيس');
    if ((_currentUserDepartment == null || _currentUserDepartment!.isEmpty) &&
        isHOD &&
        (userId != null && userId.isNotEmpty)) {
      DatabaseHelper.instance.database.then((db) {
        db.query(
          'departments',
          where: 'hod_id = ?',
          whereArgs: [userId],
          limit: 1,
        ).then((depts) {
          if (depts.isNotEmpty) {
            _currentUserDepartment = depts.first['name']?.toString() ?? '';
            startListening();
          }
        });
      }).catchError((e) {
        debugPrint('Error loading department for HOD in setUserData: $e');
      });
    }

    startListening();
    loadCollegeDepartments();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isManualMode) return;

    _currentUserRole = prefs.getString('userRole') ?? 'Admin';
    _currentUserName = prefs.getString('userName') ?? 'المدير العام';
    _currentUserCollege =
        prefs.getString('college') ?? 'نيابة الشؤون الأكاديمية';
    _currentUserId = prefs.getString('userId') ?? '';
    _currentUserDepartment = prefs.getString('userDepartment') ?? '';

    // إذا كان رئيس قسم والمسار فارغ، نتحقق من قاعدة البيانات المحلية (SQLite)
    final bool isHOD = (_currentUserRole ?? '').toLowerCase().contains('head') ||
                       (_currentUserRole ?? '').contains('رئيس');
    if ((_currentUserDepartment == null || _currentUserDepartment!.isEmpty) &&
        isHOD &&
        (_currentUserId != null && _currentUserId!.isNotEmpty)) {
      try {
        final db = await DatabaseHelper.instance.database;
        final depts = await db.query(
          'departments',
          where: 'hod_id = ?',
          whereArgs: [_currentUserId!],
          limit: 1,
        );
        if (depts.isNotEmpty) {
          _currentUserDepartment = depts.first['name']?.toString() ?? '';
          await prefs.setString('userDepartment', _currentUserDepartment!);
        }
      } catch (e) {
        debugPrint('Error loading department for HOD in RequestViewModel: $e');
      }
    }

    startListening();
    loadCollegeDepartments();
  }

  String _normalizeArabic(String text) {
    String t = text.trim().toLowerCase();
    t = t.replaceAll(RegExp(r'[\u064B-\u0652]'), ''); // إزالة التشكيل
    t = t.replaceAll(RegExp(r'[أإآ]'), 'ا'); // توحيد الألف
    t = t.replaceAll('ة', 'ه'); // توحيد التاء المربوطة
    t = t.replaceAll('ى', 'ي'); // توحيد الياء
    t = t.replaceAll('ال', ''); // إزالة ال التعريف
    t = t.replaceAll(RegExp(r'\s+'), ''); // إزالة المسافات
    return t;
  }

  bool _isSameDepartment(String deptA, String deptB) {
    final a = _normalizeArabic(deptA);
    final b = _normalizeArabic(deptB);
    if (a == b) return true;
    return a.contains(b) || b.contains(a);
  }

  bool isSameDepartment(String deptA, String deptB) {
    return _isSameDepartment(deptA, deptB);
  }

  bool _isSameCollege(String collegeA, String collegeB) {
    final a = collegeA.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final b = collegeB.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (a == b) return true;

    final cleanA =
        a.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'（.*?）'), '');
    final cleanB =
        b.replaceAll(RegExp(r'\(.*?\)'), '').replaceAll(RegExp(r'（.*?）'), '');
    if (cleanA == cleanB) return true;

    return cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }

  bool _shouldShowRequest(RequestModel req) {
    if (req.senderId == _currentUserId) return false;

    final String role = (_currentUserRole ?? '').toLowerCase();
    final String college = (_currentUserCollege ?? '').toLowerCase();

    // تحليل قائمة الأدوار (لأنه قد يكون JSON Array أو نص منفرد)
    List<String> userRoles = [];
    if (role.startsWith('[')) {
      try {
        userRoles = List<String>.from(jsonDecode(role))
            .map((r) => r.toLowerCase())
            .toList();
      } catch (_) {}
    }
    if (userRoles.isEmpty) {
      userRoles = [role];
    }

    final bool isDeptHead = userRoles.any((r) =>
        r.contains('dept_head') ||
        r.contains('dept head') ||
        r.contains('head of department') ||
        r.contains('رئيس قسم') ||
        r.contains('رئيس القسم'));
    final bool isViceDean = userRoles.any((r) =>
        r.contains('vice_dean') ||
        r.contains('vice dean') ||
        r.contains('نائب العميد') ||
        r.contains('نائب عميد'));
    final bool isDean = userRoles.any((r) =>
        (r.contains('dean') && !r.contains('vice')) || r.contains('عميد'));
    final bool isAcademicAffairs = userRoles.any((r) =>
        r.contains('prosecution') ||
        (r.contains('academic') && !r.contains('vice')) ||
        r.contains('admin') ||
        college.contains('نيابة') ||
        college.contains('الأكاديمية'));

    if (req.status == 'مرفوض') {
      return false;
    }
    if (req.status == 'مقبول') {
      if (!isAcademicAffairs) {
        return false;
      }
    }

    // للطلبات غير النيابة العامة، نتحقق من تطابق الكلية أولاً لغير النيابة الأكاديمية
    if (!isAcademicAffairs) {
      final bool matchesCollege = _isSameCollege(req.destinationCollege, _currentUserCollege ?? '') ||
                                  (req.status == 'قيد الانتظار' && _isSameCollege(req.senderCollege, _currentUserCollege ?? ''));
      if (!matchesCollege) {
        return false;
      }
    }

    // إذا كان رئيس قسم (وليس عميداً أو نائباً للعميد)، يجب أن يطابق قسم مرسل الطلب قسم رئيس القسم الحالي
    if (isDeptHead && !isAcademicAffairs && !isViceDean && !isDean) {
      final dept = req.extraData?['sender_department']?.toString().trim();
      final myDept = _currentUserDepartment?.trim();
      if (dept != null && myDept != null) {
        if (!_isSameDepartment(dept, myDept)) {
          return false; // لا يطابق قسم رئيس القسم الحالي
        }
      }
    }

    if (req.type == 'طلب من النيابة العامة') {
      return isDean;
    }

    final bool isLeave =
        req.type == 'استمارة طلب إجازة' || req.type.contains('إجازة');
    if (isLeave) {
      final int step = req.extraData?['current_step_order'] != null
          ? (req.extraData!['current_step_order'] is int
              ? req.extraData!['current_step_order'] as int
              : int.tryParse(req.extraData!['current_step_order'].toString()) ??
                  1)
          : 1;

      bool canSee = false;

      if (isDeptHead && step >= 1) {
        canSee = true; // تحقق القسم تم بالفعل أعلاه
      }
      if (isViceDean && step >= 2) {
        canSee = true;
      }
      if (isDean && step >= 3) {
        canSee = true;
      }
      if (isAcademicAffairs && step >= 4) {
        canSee = true;
      }

      return canSee;
    }

    // بالنسبة للطلبات الأخرى (غير الإجازات)
    if (isAcademicAffairs) {
      return ['نيابة الشؤون الأكاديمية', 'جميع الكليات']
          .contains(req.destinationCollege);
    } else {
      return true; // تمت تصفية الكلية والقسم أعلاه بالفعل
    }
  }

  void startListening() {
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();

    _isLoading = true;
    notifyListeners();

    Query queryReceived;
    String role = (_currentUserRole ?? '').toLowerCase();
    String college = (_currentUserCollege ?? '');

    // 👈 طباعة للتصحيح لمعرفة قيم المستخدم الحالية في سجلات المطورين
    debugPrint('[REQUEST DEBUG] Role: $role, College: $college');

    // 👈 النيابة الأكاديمية أو الإدارة: نتحقق من الكلمات المفتاحية في الدور أو اسم الكلية
    if (role.contains('admin') ||
        role.contains('prosecution') ||
        role.contains('deanship') ||
        (role.contains('academic') && !role.contains('vice')) ||
        college.contains('نيابة') ||
        college.contains('الأكاديمية')) {
      queryReceived = _firestore.collection('requests').where(
          'destinationCollege',
          whereIn: ['نيابة الشؤون الأكاديمية', 'جميع الكليات']);
    } else {
      // 👈 تم التعديل لجلب كافة الطلبات وتصفيتها محلياً بمرونة باستخدام _isSameCollege
      // لتجنب مشاكل عدم التطابق الحرفي لأسماء الكليات في الاستعلام المباشر من Firestore (مثال: "كلية الحاسبات" مقابل "الحاسبات")
      queryReceived = _firestore.collection('requests');
    }

    _receivedSubscription = queryReceived
        .snapshots() // أزلنا orderBy من الاستعلام لتجنب مشاكل الـ Index
        .listen((snapshot) async {
      _receivedRequests = snapshot.docs
          .map((doc) =>
              RequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where(_shouldShowRequest)
          .toList();

      // 👈 ترتيب يدوي في الذاكرة لضمان ظهور الأحدث أولاً بدون الحاجة لـ Index
      _receivedRequests.sort((a, b) => b.dateSent.compareTo(a.dateSent));

      // حفظ في القاعدة المحلية بذكاء
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> localData = Map<String, dynamic>.from(data);

        localData['id'] = doc.id;
        localData['dateSent'] = _formatDateForSqlite(data['dateSent']);
        localData['dateReplied'] = _formatDateForSqlite(data['dateReplied']);

        // 👈 تحويل الخريطة إلى نص JSON قبل الحفظ في SQLite
        if (localData['extraData'] != null && localData['extraData'] is Map) {
          localData['extraData'] = jsonEncode(localData['extraData']);
        }

        try {
          await DatabaseHelper.instance.insertRequestLocal(localData);
        } catch (e) {
          debugPrint('[SQLITE DEBUG] ❌ فشل حفظ الطلب الوارد محلياً: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
    }, onError: (e) async {
      debugPrint('خطأ في جلب الطلبات الواردة (ربما بسبب الأوفلاين): $e');
      await _loadLocalRequests();
      _isLoading = false;
      notifyListeners();
    });

    // 👈 الطلبات الصادرة: نفلتر بمعرف المستخدم نفسه لضمان الخصوصية
    Query sentQuery = _firestore.collection('requests');

    // إذا كان مديراً، ربما يريد رؤية كل الصادر؟ لكن حالياً نلتزم بطلبه وهو رؤية طلباته الشخصية
    sentQuery = sentQuery.where('senderId', isEqualTo: _currentUserId);

    _sentSubscription = sentQuery
        .snapshots() // أزلنا orderBy لتجنب مشاكل الـ Index
        .listen((snapshot) async {
      _sentRequests = snapshot.docs
          .map((doc) =>
              RequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // 👈 ترتيب يدوي في الذاكرة
      _sentRequests.sort((a, b) => b.dateSent.compareTo(a.dateSent));

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> localData = Map<String, dynamic>.from(data);

        localData['id'] = doc.id;
        localData['dateSent'] = _formatDateForSqlite(data['dateSent']);
        localData['dateReplied'] = _formatDateForSqlite(data['dateReplied']);

        // 👈 تحويل الخريطة إلى نص JSON
        if (localData['extraData'] != null && localData['extraData'] is Map) {
          localData['extraData'] = jsonEncode(localData['extraData']);
        }

        try {
          await DatabaseHelper.instance.insertRequestLocal(localData);
        } catch (e) {
          debugPrint('[SQLITE DEBUG] ❌ فشل حفظ الطلب الصادر محلياً: $e');
        }
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('خطأ في جلب الطلبات الصادرة: $e');
    });
  }

  Future<void> _loadLocalRequests() async {
    final localData = await DatabaseHelper.instance.getLocalRequests();
    if (localData.isNotEmpty) {
      final allLocal =
          localData.map((map) => RequestModel.fromMap(map, map['id'])).toList();

      _receivedRequests = allLocal.where(_shouldShowRequest).toList();

      // فلترة المحلي أيضاً بالمعرف والترتيب
      _sentRequests =
          allLocal.where((r) => r.senderId == _currentUserId).toList();

      _receivedRequests.sort((a, b) => b.dateSent.compareTo(a.dateSent));
      _sentRequests.sort((a, b) => b.dateSent.compareTo(a.dateSent));
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // 👈 تحديد أن الكائن قد تم إغلاقه
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners(); // 👈 لا يتم التحديث إلا إذا كان الكائن حياً
    }
  }

  Future<void> refreshRequests() async {
    startListening();
  }

  Future<PlatformFile?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        // 👈 تعديل بسيط للتوافق
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result != null) {
        return result.files.first;
      }
    } catch (e) {
      _errorMessage = 'خطأ في اختيار الملف: $e';
      notifyListeners();
    }
    return null;
  }

  /// رفع بايتات ملف ثنائي عبر REST API الخاص بـ Firebase Storage
  /// لتفادي مشكلة الانهيار (C++ Runtime Crash) على تطبيق الديسكتوب في Windows.
  Future<String> _uploadBytesRest(
      List<int> bytes, String storagePath, String contentType) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    final idToken = await currentUser?.getIdToken();
    final bucketName = _storage.app.options.storageBucket;

    final client = HttpClient();
    try {
      final uri = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucketName/o?name=${Uri.encodeComponent(storagePath)}');
      final request = await client.postUrl(uri);

      request.headers.set('Content-Type', contentType);
      if (idToken != null) {
        request.headers.set('Authorization', 'Bearer $idToken');
      }

      request.add(bytes);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
        final String? downloadToken = jsonResponse['downloadTokens'];
        if (downloadToken != null && downloadToken.isNotEmpty) {
          return 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o/${Uri.encodeComponent(storagePath)}?alt=media&token=$downloadToken';
        }
        throw Exception('No downloadTokens found in response');
      } else {
        throw Exception(
            'Upload failed: ${response.statusCode} - $responseBody');
      }
    } finally {
      client.close();
    }
  }

  /// مساعد لتنسيق التاريخ المسترجع من الموافقات
  String _formatIsoDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  /// رفع الملف مباشرة إلى مجلد العضو في Firebase Storage
  Future<String?> _uploadFile(PlatformFile file, String memberName) async {
    try {
      String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      String storagePath = 'faculty_files/$cleanName/$fileName';

      if (!kIsWeb && Platform.isWindows) {
        debugPrint(
            '🚀 [ATTACHMENT] Using REST API for attachment upload on Windows...');
        final bytes = await File(file.path!).readAsBytes();
        return await _uploadBytesRest(
          bytes,
          storagePath,
          'application/octet-stream',
        );
      } else {
        Reference ref = _storage.ref().child(storagePath);
        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = ref.putData(file.bytes!);
        } else {
          final bytes = await File(file.path!).readAsBytes();
          uploadTask = ref.putData(bytes);
        }
        TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('خطأ في رفع الملف: $e');
      return null;
    }
  }

  /// حفظ الملف محلياً في مجلد العضو الدائم
  Future<String?> _saveFileLocally(PlatformFile file, String memberName) async {
    if (kIsWeb) return null;
    try {
      String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final directory = await getApplicationDocumentsDirectory();
      final memberDir = Directory(
          p.join(directory.path, 'AcademicAffairs', 'FacultyFiles', cleanName));
      if (!await memberDir.exists()) {
        await memberDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final localPath = p.join(memberDir.path, fileName);

      if (file.path != null) {
        await File(file.path!).copy(localPath);
      } else if (file.bytes != null) {
        await File(localPath).writeAsBytes(file.bytes!);
      }

      return localPath;
    } catch (e) {
      debugPrint('خطأ في حفظ الملف محلياً: $e');
      return null;
    }
  }

  Future<List<String>?> downloadFile(RequestModel request) async {
    if (request.fileUrl == null || request.fileUrl!.isEmpty) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final directory = await getApplicationDocumentsDirectory();
      final archiveDir = Directory(p.join(directory.path, 'archived_requests'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }

      Map<String, List<String>> urlsMap = _parseJsonMap(request.fileUrl);
      List<String> urls = [];
      urlsMap.values.forEach((list) => urls.addAll(list));

      List<String> localPaths = [];
      for (int i = 0; i < urls.length; i++) {
        String url = urls[i];
        if (url.isEmpty) continue;

        String ext = '.pdf';
        try {
          String rawPath = Uri.parse(url).path;
          String possibleExt =
              rawPath.split('.').last.split('?').first.toLowerCase();
          if (possibleExt.length <= 5) ext = '.$possibleExt';
        } catch (_) {}

        String fileName =
            'downloaded_${DateTime.now().millisecondsSinceEpoch}_$i$ext';
        final localPath = p.join(archiveDir.path, fileName);
        final File file = File(localPath);

        await _storage.refFromURL(url).writeToFile(file);
        localPaths.add(localPath);
      }

      String localPathsJson = jsonEncode(localPaths);
      await DatabaseHelper.instance
          .updateRequestLocalPath(request.id, localPathsJson);

      _isLoading = false;
      notifyListeners();
      return localPaths.isNotEmpty ? localPaths : null;
    } catch (e) {
      debugPrint('خطأ أثناء تحميل الملف: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendRequest({
    required String title,
    required String destinationCollege,
    required String type,
    required String description,
    List<PlatformFile>? attachedFiles, // 👈 دعم عدة ملفات
    String? applicantName,
    String? senderCollege,
    Map<String, dynamic>? extraData,
  }) async {
    _isSending = true;
    _errorMessage = '';
    notifyListeners();

    try {
      String? fileUrlsJson;
      String? localPathsJson;

      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        List<String> urls = [];
        List<String> locals = [];
        // اسم العضو لتنظيم مسارات الملفات
        String memberName = applicantName ?? _currentUserName ?? 'unknown';

        for (var file in attachedFiles) {
          // حفظ محلي في مجلد العضو الدائم
          String? local = await _saveFileLocally(file, memberName);
          // رفع مباشرة إلى مسار العضو في Firebase Storage
          String? url = await _uploadFile(file, memberName);

          if (url != null) {
            urls.add(url);
            if (local != null) locals.add(local);
          }
        }

        if (urls.isNotEmpty) {
          fileUrlsJson = jsonEncode(urls);
          localPathsJson = jsonEncode(locals);
        }
      }

      final newRequest = RequestModel(
        id: '',
        title: title,
        applicantName: applicantName ?? _currentUserName ?? 'غير معروف',
        senderCollege: senderCollege ?? _currentUserCollege ?? 'غير معروف',
        destinationCollege: destinationCollege,
        type: type,
        description: description,
        dateSent: DateTime.now(),
        status: 'قيد الانتظار',
        fileUrl: fileUrlsJson, // تخزين كـ JSON
        localFilePath: localPathsJson, // تخزين كـ JSON
        senderId: _currentUserId,
        extraData: extraData,
      );

      final docRef =
          await _firestore.collection('requests').add(newRequest.toMap());

      // معالجة الموافقات التلقائية المترتبة على أدوار منشئ الطلب
      final createdDoc = await docRef.get();
      if (createdDoc.exists) {
        await _processAutoApprovals(
            docRef, createdDoc.data() as Map<String, dynamic>);
        
        // جلب الطلب المحدث بعد الموافقات التلقائية لإرسال الإشعار الصحيح
        final updatedDoc = await docRef.get();
        if (updatedDoc.exists) {
          final updatedRequest = RequestModel.fromMap(
            updatedDoc.data() as Map<String, dynamic>,
            updatedDoc.id,
          );
          unawaited(_sendNotificationsForRequest(updatedRequest, isNewRequest: true));
        }
      }

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في إرسال الطلب: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToRequest(String requestId, String status,
      {String? rejectionReason,
      List<String>? approvedFields,
      List<PlatformFile>? attachedFiles}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. جلب بيانات الطلب
      final requestDoc =
          await _firestore.collection('requests').doc(requestId).get();
      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data() as Map<String, dynamic>;
      final String type = requestData['type'] ?? '';
      final String? senderId = requestData['senderId'];
      final Map<String, dynamic>? extraData = requestData['extraData'] != null
          ? Map<String, dynamic>.from(requestData['extraData'])
          : null;

      // 2. تحديد دور وخطوة المستخدم الحالي مع دعم تعدد الأدوار
      final currentRole = _currentUserRole ?? '';
      final lowerRole = currentRole.toLowerCase();
      final lowerCollege = (_currentUserCollege ?? '').toLowerCase();

      // تحليل قائمة الأدوار (لأنه قد يكون JSON Array أو نص منفرد)
      List<String> userRoles = [];
      if (lowerRole.startsWith('[')) {
        try {
          userRoles = List<String>.from(jsonDecode(lowerRole))
              .map((r) => r.toLowerCase())
              .toList();
        } catch (_) {}
      }
      if (userRoles.isEmpty) {
        userRoles = [lowerRole];
      }

      bool hasDeptHead = userRoles.any((r) =>
          r.contains('dept_head') ||
          r.contains('dept head') ||
          r.contains('head of department') ||
          r.contains('رئيس قسم') ||
          r.contains('رئيس القسم'));
      bool hasViceDean = userRoles.any((r) =>
          r.contains('vice_dean') ||
          r.contains('vice dean') ||
          r.contains('نائب العميد') ||
          r.contains('نائب عميد'));
      bool hasDean = userRoles.any((r) =>
          (r.contains('dean') && !r.contains('vice')) || r.contains('عميد'));
      bool hasAcademicAffairs = userRoles.any((r) =>
          r.contains('prosecution') ||
          (r.contains('academic') && !r.contains('vice')) ||
          r.contains('admin') ||
          lowerCollege.contains('نيابة') ||
          lowerCollege.contains('الأكاديمية'));

      int reqStep = extraData?['current_step_order'] != null
          ? (extraData!['current_step_order'] is int
              ? extraData['current_step_order'] as int
              : int.tryParse(extraData['current_step_order'].toString()) ?? 1)
          : 1;

      int currentStep = 1;
      String roleLabel = 'رئيس القسم';

      if (reqStep == 1 && hasDeptHead) {
        currentStep = 1;
        roleLabel = 'رئيس القسم';
      } else if (reqStep == 2 && hasViceDean) {
        currentStep = 2;
        roleLabel = 'نائب العميد للشؤون الأكاديمية';
      } else if (reqStep == 3 && hasDean) {
        currentStep = 3;
        roleLabel = 'عميد الكلية';
      } else if (reqStep == 4 && hasAcademicAffairs) {
        currentStep = 4;
        roleLabel = 'نائب رئيس الجامعة للشؤون الأكاديمية';
      } else {
        // Fallback: إذا لم يتطابق مع خطوة الطلب الحالية، نأخذ أعلى دور يملكه المستخدم
        if (hasAcademicAffairs) {
          currentStep = 4;
          roleLabel = 'نائب رئيس الجامعة للشؤون الأكاديمية';
        } else if (hasDean) {
          currentStep = 3;
          roleLabel = 'عميد الكلية';
        } else if (hasViceDean) {
          currentStep = 2;
          roleLabel = 'نائب العميد للشؤون الأكاديمية';
        } else {
          currentStep = 1;
          roleLabel = 'رئيس القسم';
        }
      }

      bool isLeaveRequest =
          (type == 'استمارة طلب إجازة' || type.contains('إجازة'));
      String statusToUpdate = status;
      String destinationCollegeToUpdate =
          requestData['destinationCollege'] ?? '';
      final updatedExtraData = Map<String, dynamic>.from(extraData ?? {});

      // 👈 رفع ملفات الرد إن وجدت وحفظ مساراتها
      if (attachedFiles != null && attachedFiles.isNotEmpty) {
        List<String> urls = [];
        List<String> locals = [];
        String replierName = _currentUserName ?? 'unknown';

        for (var file in attachedFiles) {
          String? local = await _saveFileLocally(file, 'replies_$replierName');
          String? url = await _uploadFile(file, 'replies_$replierName');
          if (url != null) {
            urls.add(url);
            if (local != null) locals.add(local);
          }
        }
        if (urls.isNotEmpty) {
          updatedExtraData['reply_attachments'] = urls;
          updatedExtraData['reply_local_paths'] = locals;
        }
      }

      if (isLeaveRequest) {
        if (status == 'مقبول') {
          List<dynamic> approvalHistory = extraData?['approval_history'] != null
              ? List<dynamic>.from(extraData?['approval_history'])
              : [];

          String getRoleLabelForStep(int s) {
            switch (s) {
              case 1:
                return 'رئيس القسم';
              case 2:
                return 'نائب العميد للشؤون الأكاديمية';
              case 3:
                return 'عميد الكلية';
              case 4:
                return 'نائب رئيس الجامعة للشؤون الأكاديمية';
              default:
                return 'مراجع';
            }
          }

          int stepToProcess = currentStep;
          bool keepApproving = true;

          while (keepApproving) {
            final stepLabel = getRoleLabelForStep(stepToProcess);
            final alreadyApproved = approvalHistory.any((s) => s is Map && s['step'] == stepToProcess);
            if (!alreadyApproved) {
              approvalHistory.add({
                'step': stepToProcess,
                'approver_role': stepLabel,
                'approver_name': _currentUserName ?? 'غير معروف',
                'date': DateTime.now().toIso8601String(),
              });
            }

            if (stepToProcess < 4) {
              int nextStep = stepToProcess + 1;
              bool canApproveNext = false;
              if (nextStep == 2 && hasViceDean) {
                canApproveNext = true;
              } else if (nextStep == 3 && hasDean) {
                canApproveNext = true;
              } else if (nextStep == 4 && hasAcademicAffairs) {
                canApproveNext = true;
              }

              if (canApproveNext) {
                stepToProcess = nextStep;
              } else {
                statusToUpdate = 'قيد الانتظار';
                updatedExtraData['current_step_order'] = nextStep;
                if (nextStep == 4) {
                  destinationCollegeToUpdate = 'نيابة الشؤون الأكاديمية';
                }
                keepApproving = false;
              }
            } else {
              statusToUpdate = 'مقبول';
              updatedExtraData['current_step_order'] = 4;
              keepApproving = false;
            }
          }

          updatedExtraData['approval_history'] = approvalHistory;
        } else if (status == 'مرفوض') {
          statusToUpdate = 'مرفوض';
          updatedExtraData['rejected_by_role'] = roleLabel;
          updatedExtraData['rejected_by_name'] =
              _currentUserName ?? 'غير معروف';
        }
      }

      // 2. تحديث الطلب في السحابة
      final requestDocRef = _firestore.collection('requests').doc(requestId);
      await requestDocRef.update({
        'status': statusToUpdate,
        'rejectionReason': rejectionReason,
        'destinationCollege': destinationCollegeToUpdate,
        'extraData': updatedExtraData,
        'dateReplied': FieldValue.serverTimestamp(),
      });

      // معالجة الموافقات التلقائية للمراحل التالية
      if (statusToUpdate == 'قيد الانتظار') {
        final updatedDoc = await requestDocRef.get();
        if (updatedDoc.exists) {
          await _processAutoApprovals(
              requestDocRef, updatedDoc.data() as Map<String, dynamic>);
        }
      }

      // جلب الطلب النهائي لإرسال الإشعار المناسب
      final finalDoc = await requestDocRef.get();
      if (finalDoc.exists) {
        final finalRequest = RequestModel.fromMap(
          finalDoc.data() as Map<String, dynamic>,
          finalDoc.id,
        );
        unawaited(_sendNotificationsForRequest(finalRequest, isNewRequest: false));
      }

      // 2.5. توليد استمارة طلب إجازة ورفعها عند القبول النهائي (الخطوة 4) (تم التعطيل مؤقتاً لتوليدها محلياً بناءً على طلب المستخدم)
      /*
      if (isLeaveRequest && status == 'مقبول' && currentStep == 4) {
        try {
          debugPrint('🚀 [LEAVE REQUEST] Generating and archiving leave request document...');
          final applicantName = requestData['applicantName'] ?? 'غير معروف';
          final senderCollege = requestData['senderCollege'] ?? 'غير معروف';
          final senderDepartment = extraData?['sender_department'] ?? 'غير معروف';
          final leaveType = extraData?['leave_type'] ?? 'إجازة';
          final duration = extraData?['duration']?.toString() ?? '....................';
          final startDate = extraData?['start_date'] != null
              ? _formatIsoDate(extraData?['start_date'])
              : '....................';
          final requestDate = extraData?['request_date'] != null
              ? _formatIsoDate(extraData?['request_date'])
              : '....................';

          final docxBytes = await DocxExportService.createLeaveRequestDocx(
            applicantName: applicantName,
            college: senderCollege,
            department: senderDepartment,
            leaveType: leaveType,
            duration: '$duration أيام',
            startDate: startDate,
            requestDate: requestDate,
            approvalHistory: updatedExtraData['approval_history'] ?? [],
          );

          final String storagePath = 'faculty_files/archived_requests/$requestId.docx';
          String downloadUrl;

          if (!kIsWeb && Platform.isWindows) {
            debugPrint('🚀 [ARCHIVE] Using REST API for uploading leave request on Windows...');
            downloadUrl = await _uploadBytesRest(
              docxBytes,
              storagePath,
              'application/msword',
            );
          } else {
            final ref = _storage.ref().child(storagePath);
            final uploadTask = await ref.putData(
              Uint8List.fromList(docxBytes),
              SettableMetadata(contentType: 'application/msword'),
            );
            downloadUrl = await uploadTask.ref.getDownloadURL();
          }

          updatedExtraData['archived_docx_url'] = downloadUrl;

          await _firestore.collection('requests').doc(requestId).update({
            'extraData': updatedExtraData,
          });
          debugPrint('✅ [LEAVE REQUEST] Document uploaded: $downloadUrl');
        } catch (e) {
          debugPrint('❌ [LEAVE REQUEST] Failed to generate/upload leave request: $e');
        }
      }
      */

      // 3. التحديث التلقائي لبيانات العضو عند الموافقة (كلياً أو جزئياً)
      if ((status == 'مقبول' || status == 'مقبول جزئياً') &&
          type == 'تعديل معلومات' &&
          senderId != null) {
        debugPrint('[AUTO-UPDATE] 🚀 جاري تحديث بيانات العضو $senderId...');
        try {
          Map<String, dynamic> facultyData = {};
          Map<String, dynamic> userData = {};

          // ترجمة المفاتيح من camelCase إلى snake_case
          final keyMap = {
            'fileNumber': 'file_number',
            'idCardNumber': 'id_card_number',
            'jobNumber': 'job_number',
            'birthPlace': 'birth_place',
            'birthDate': 'birth_date',
            'firstAppointmentDate': 'first_appointment_date',
            'universityAppointmentDate': 'university_appointment_date',
            'bscDegree': 'bsc_degree',
            'bscDate': 'bsc_date',
            'bscUniversity': 'bsc_university',
            'bscCountry': 'bsc_country',
            'bscAcademicTitle': 'bsc_academic_title',
            'bscTitleTransferDate': 'bsc_title_transfer_date',
            'bscSpecialization': 'bsc_specialization',
            'mscDegree': 'msc_degree',
            'mscDate': 'msc_date',
            'mscUniversity': 'msc_university',
            'mscCountry': 'msc_country',
            'mscAcademicTitle': 'msc_academic_title',
            'mscTitleTransferDate': 'msc_title_transfer_date',
            'mscDecisionNumber': 'msc_decision_number',
            'mscExactSpecialization': 'msc_exact_specialization',
            'currentDegree': 'current_degree',
            'currentDegreeDate': 'current_degree_date',
            'currentUniversity': 'current_university',
            'currentCountry': 'current_country',
            'assistantProfDate': 'assistant_prof_date',
            'assistantProfDecision': 'assistant_prof_decision',
            'assocProfDate': 'assoc_prof_date',
            'assocProfDecision': 'assoc_prof_decision',
            'currentAcademicTitle': 'current_academic_title',
            'titleTransferDate': 'title_transfer_date',
            'generalSpecialization': 'general_specialization',
            'exactSpecialization': 'exact_specialization',
          };

          String? facultyDocId = extraData?['faculty_doc_id']?.toString();
          Map<String, dynamic> currentMember = {};

          String targetUserId = senderId ?? '';

          if (facultyDocId != null && facultyDocId.isNotEmpty) {
            final fsDoc = await _firestore
                .collection('faculty_members')
                .doc(facultyDocId)
                .get();
            if (fsDoc.exists) {
              currentMember = Map<String, dynamic>.from(fsDoc.data() as Map);
              targetUserId =
                  currentMember['user_id']?.toString() ?? senderId ?? '';
            }
          } else {
            final fsQuery = await _firestore
                .collection('faculty_members')
                .where('user_id', isEqualTo: senderId)
                .limit(1)
                .get();

            if (fsQuery.docs.isNotEmpty) {
              facultyDocId = fsQuery.docs.first.id;
              currentMember =
                  Map<String, dynamic>.from(fsQuery.docs.first.data());
              targetUserId = senderId ?? '';
            }
          }

          if (currentMember.isEmpty) {
            // fallback: ابحث في SQLite المحلي
            final db = await DatabaseHelper.instance.database;
            final localRec = await db.query('faculty_members',
                where: 'id = ? OR user_id = ?',
                whereArgs: [facultyDocId ?? '', senderId ?? ''],
                limit: 1);
            if (localRec.isNotEmpty) {
              facultyDocId ??= localRec.first['id']?.toString();
              currentMember = Map<String, dynamic>.from(localRec.first);
              targetUserId =
                  currentMember['user_id']?.toString() ?? senderId ?? '';
            }
          }

          extraData?.forEach((key, value) {
            if (key == 'new_files_mapping') return;
            if (key == 'deleted_files') return;
            if (key == 'faculty_doc_id') return;
            // تجاهل الحقول المرفوضة
            if (approvedFields != null && !approvedFields.contains(key)) return;

            if (key == 'email') {
              userData['pending_email'] = value;
            } else {
              if (key == 'name' ||
                  key == 'department' ||
                  key == 'idCardNumber') {
                userData[key] = value;
              }
              facultyData[keyMap[key] ?? key] = value;
            }
          });

          if (facultyDocId == null || currentMember.isEmpty) {
            debugPrint(
                '[AUTO-UPDATE] ⚠️ لم يتم العثور على سجل العضو: $targetUserId');
          } else {
            // معالجة الملفات المرفقة في الطلب
            final String? reqFileUrl = requestData['fileUrl']?.toString();

            if (reqFileUrl != null && reqFileUrl.isNotEmpty) {
              // القوائم الحالية للعضو كخرائط
              Map<String, List<String>> currentUrlsMap =
                  _parseJsonMap(currentMember['file_url']);
              Map<String, List<String>> currentLocalPathsMap =
                  _parseJsonMap(currentMember['local_file_path']);

              // الروابط الجديدة من الطلب (مرفوعة مسبقاً إلى faculty_files/{name}/)
              List<String> newUrls = _parseJsonList(reqFileUrl);
              if (newUrls.isEmpty && reqFileUrl.isNotEmpty)
                newUrls = [reqFileUrl];

              // المسارات المحلية من الطلب (محفوظة مسبقاً في AcademicAffairs/FacultyFiles/{name}/)
              String? reqLocalPath = requestData['localFilePath']?.toString();
              List<String> newLocalPaths =
                  reqLocalPath != null ? _parseJsonList(reqLocalPath) : [];

              // قراءة التعيينات (Mapping) من extraData
              Map<String, dynamic> filesMapping = {};
              if (extraData != null && extraData['new_files_mapping'] != null) {
                try {
                  filesMapping =
                      Map<String, dynamic>.from(extraData['new_files_mapping']);
                } catch (_) {}
              }

              // إضافة الملفات الجديدة للقوائم الحالية للعضو بدون إعادة رفع
              for (int i = 0; i < newUrls.length; i++) {
                String url = newUrls[i];
                if (url.isEmpty) continue;
                String localPath =
                    i < newLocalPaths.length ? newLocalPaths[i] : '';

                // تحديد الفئة
                String category = 'others';
                try {
                  filesMapping.forEach((k, v) {
                    if (v is List &&
                        (v.contains(i) || v.contains(i.toString()))) {
                      category = k;
                    }
                  });
                } catch (_) {}

                // إذا المسار المحلي غير موجود أو الملف محذوف، حمّله من Storage
                if (localPath.isEmpty || !File(localPath).existsSync()) {
                  try {
                    String cleanName = (currentMember['name'] ?? 'unknown')
                        .toString()
                        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                    Directory appDocDir =
                        await getApplicationDocumentsDirectory();
                    String memberDirPath = p.join(appDocDir.path,
                        'AcademicAffairs', 'FacultyFiles', cleanName);
                    if (!await Directory(memberDirPath).exists()) {
                      await Directory(memberDirPath).create(recursive: true);
                    }
                    String ext = '.pdf';
                    try {
                      String rawPath = Uri.parse(url).path;
                      String possibleExt = rawPath
                          .split('.')
                          .last
                          .split('?')
                          .first
                          .toLowerCase();
                      if (possibleExt.length <= 5) ext = '.$possibleExt';
                    } catch (_) {}
                    String fileName =
                        '${DateTime.now().millisecondsSinceEpoch}_$i$ext';
                    localPath = p.join(memberDirPath, fileName);
                    await _storage.refFromURL(url).writeToFile(File(localPath));
                    debugPrint(
                        '[AUTO-UPDATE] ✅ تم تحميل الملف $i محلياً: $localPath');
                  } catch (e) {
                    debugPrint(
                        '[AUTO-UPDATE] ⚠️ فشل تحميل الملف $i محلياً: $e');
                    localPath = '';
                  }
                }

                currentUrlsMap.putIfAbsent(category, () => []).add(url);
                currentLocalPathsMap
                    .putIfAbsent(category, () => [])
                    .add(localPath);
              }

              facultyData['file_url'] = jsonEncode(currentUrlsMap);
              facultyData['local_file_path'] = jsonEncode(currentLocalPathsMap);
            }

            // معالجة الملفات المحذوفة
            if (extraData != null && extraData['deleted_files'] != null) {
              List<dynamic> deletedUrlsRaw = extraData['deleted_files'];
              List<String> deletedUrls =
                  deletedUrlsRaw.map((e) => e.toString()).toList();

              if (deletedUrls.isNotEmpty) {
                // القوائم الحالية (سواء تم تحديثها بالملفات الجديدة أم لا)
                Map<String, List<String>> currentUrlsMap = _parseJsonMap(
                    facultyData['file_url']?.toString() ??
                        currentMember['file_url']?.toString() ??
                        '');
                Map<String, List<String>> currentLocalPathsMap = _parseJsonMap(
                    facultyData['local_file_path']?.toString() ??
                        currentMember['local_file_path']?.toString() ??
                        '');

                for (String delUrl in deletedUrls) {
                  if (delUrl.isEmpty) continue;

                  // حذف من السحابة
                  try {
                    await _storage.refFromURL(delUrl).delete();
                    debugPrint(
                        '[AUTO-UPDATE] 🗑️ تم حذف الملف من السحابة: $delUrl');
                  } catch (e) {
                    debugPrint('[AUTO-UPDATE] ⚠️ فشل حذف الملف من السحابة: $e');
                  }

                  // حذف من القوائم
                  String foundCategory = '';
                  int foundIndex = -1;

                  currentUrlsMap.forEach((cat, urls) {
                    int idx = urls.indexOf(delUrl);
                    if (idx != -1) {
                      foundCategory = cat;
                      foundIndex = idx;
                    }
                  });

                  if (foundCategory.isNotEmpty && foundIndex != -1) {
                    currentUrlsMap[foundCategory]!.removeAt(foundIndex);

                    if (currentLocalPathsMap[foundCategory] != null &&
                        currentLocalPathsMap[foundCategory]!.length >
                            foundIndex) {
                      String localPathToDelete =
                          currentLocalPathsMap[foundCategory]![foundIndex];
                      currentLocalPathsMap[foundCategory]!.removeAt(foundIndex);

                      if (localPathToDelete.isNotEmpty &&
                          File(localPathToDelete).existsSync()) {
                        try {
                          File(localPathToDelete).deleteSync();
                          debugPrint(
                              '[AUTO-UPDATE] 🗑️ تم حذف الملف محلياً: $localPathToDelete');
                        } catch (_) {}
                      }
                    }
                  }
                }
                facultyData['file_url'] = jsonEncode(currentUrlsMap);
                facultyData['local_file_path'] =
                    jsonEncode(currentLocalPathsMap);
              }
            }
            debugPrint('[AUTO-UPDATE] 📁 تمت إضافة الملفات المصنفة بنجاح.');

            // تحديث SQLite وFirestore
            if (facultyData.isNotEmpty) {
              await DatabaseHelper.instance.updateRecordLocal(
                  'faculty_members', targetUserId, facultyData,
                  whereColumn: 'user_id');
              await _firestore
                  .collection('faculty_members')
                  .doc(facultyDocId)
                  .set(facultyData, SetOptions(merge: true));
              debugPrint(
                  '[AUTO-UPDATE] ✅ تم تحديث بيانات العضو في SQLite وFirestore.');
            }
          }

          // تحديث جدول users إذا توجد تعديلات نصية
          if (userData.isNotEmpty && targetUserId.isNotEmpty) {
            await DatabaseHelper.instance.updateRecordLocal(
                'users', targetUserId, userData,
                whereColumn: 'id');
            await _firestore
                .collection('users')
                .doc(targetUserId)
                .set(userData, SetOptions(merge: true));
          }

          debugPrint('[AUTO-UPDATE] ✅ اكتملت عملية التحديث التلقائي.');
        } catch (e) {
          debugPrint('[AUTO-UPDATE] ❌ فشل التحديث التلقائي: $e');
        }
      } else if (status == 'مقبول' && type == 'حذف ملف' && senderId != null) {
        debugPrint(
            '[AUTO-UPDATE] 🚀 جاري حذف الملف المطلوب للعضو $senderId...');
        try {
          String? categoryToDelete = extraData?['delete_file_category'];
          String? urlToDelete = extraData?['delete_file_url'];

          if (categoryToDelete != null && urlToDelete != null) {
            // جلب سجل العضو من Firestore (أحدث مصدر)
            String? facultyDocId;
            Map<String, dynamic> currentMember = {};

            final fsQuery = await _firestore
                .collection('faculty_members')
                .where('user_id', isEqualTo: senderId)
                .limit(1)
                .get();

            if (fsQuery.docs.isNotEmpty) {
              facultyDocId = fsQuery.docs.first.id;
              currentMember =
                  Map<String, dynamic>.from(fsQuery.docs.first.data());
            } else {
              final db = await DatabaseHelper.instance.database;
              final localRecord = await db.query('faculty_members',
                  where: 'user_id = ?', whereArgs: [senderId], limit: 1);
              if (localRecord.isNotEmpty) {
                currentMember = Map<String, dynamic>.from(localRecord.first);
                facultyDocId = currentMember['id']?.toString();
              }
            }

            if (facultyDocId != null && currentMember.isNotEmpty) {
              Map<String, List<String>> currentUrlsMap =
                  _parseJsonMap(currentMember['file_url']);
              Map<String, List<String>> currentLocalPathsMap =
                  _parseJsonMap(currentMember['local_file_path']);

              int indexToDelete = -1;
              if (currentUrlsMap.containsKey(categoryToDelete)) {
                indexToDelete =
                    currentUrlsMap[categoryToDelete]!.indexOf(urlToDelete);
                if (indexToDelete != -1) {
                  currentUrlsMap[categoryToDelete]!.removeAt(indexToDelete);

                  // حذف المسار المحلي المقابل إذا وجد
                  if (currentLocalPathsMap.containsKey(categoryToDelete) &&
                      currentLocalPathsMap[categoryToDelete]!.length >
                          indexToDelete) {
                    currentLocalPathsMap[categoryToDelete]!
                        .removeAt(indexToDelete);
                  }

                  // حفظ التعديلات في البيانات
                  Map<String, dynamic> facultyData = {
                    'file_url': jsonEncode(currentUrlsMap),
                    'local_file_path': jsonEncode(currentLocalPathsMap),
                  };

                  await DatabaseHelper.instance.updateRecordLocal(
                      'faculty_members', senderId, facultyData,
                      whereColumn: 'user_id');
                  await _firestore
                      .collection('faculty_members')
                      .doc(facultyDocId)
                      .set(facultyData, SetOptions(merge: true));

                  // حذف الملف من السحابة
                  try {
                    await _storage.refFromURL(urlToDelete).delete();
                    debugPrint(
                        '[AUTO-UPDATE] ✅ تم حذف الملف من السحابة: $urlToDelete');
                  } catch (e) {
                    debugPrint(
                        '[AUTO-UPDATE] ⚠️ فشل حذف الملف من السحابة (ربما غير موجود): $e');
                  }

                  debugPrint(
                      '[AUTO-UPDATE] ✅ تم تحديث بيانات العضو بعد حذف الملف.');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[AUTO-UPDATE] ❌ فشل حذف الملف التلقائي: $e');
        }
      } else if (status == 'مرفوض') {
        debugPrint(
            '[AUTO-UPDATE] 🗑️ الطلب مرفوض. جاري حذف الملفات المرفقة حتى لا تظهر في ملفات العضو...');
        try {
          // 1. حذف من السحابة
          final String? reqFileUrl = requestData['fileUrl']?.toString();
          if (reqFileUrl != null && reqFileUrl.isNotEmpty) {
            List<String> urlsToDelete = _parseJsonList(reqFileUrl);
            if (urlsToDelete.isEmpty) urlsToDelete = [reqFileUrl];
            for (String url in urlsToDelete) {
              if (url.isEmpty) continue;
              try {
                await _storage.refFromURL(url).delete();
                debugPrint('[AUTO-UPDATE] ✅ تم حذف الملف من السحابة: $url');
              } catch (e) {
                debugPrint(
                    '[AUTO-UPDATE] ⚠️ لم نتمكن من حذف الملف السحابي: $e');
              }
            }
          }

          // 2. حذف محلياً (نقوم بجلب المسار المحلي من SQLite لأن الديسكتوب قد يكون حمله للمعاينة)
          final db = await DatabaseHelper.instance.database;
          final localReq = await db.query('requests',
              where: 'id = ?', whereArgs: [requestId], limit: 1);

          List<String> pathsToDelete = [];

          // مسارات من السكوال لايت (إذا حملها النيابة)
          if (localReq.isNotEmpty && localReq.first['localFilePath'] != null) {
            String lPath = localReq.first['localFilePath'].toString();
            pathsToDelete.addAll(_parseJsonList(lPath));
            if (pathsToDelete.isEmpty && lPath.isNotEmpty)
              pathsToDelete.add(lPath);
          }

          // مسارات من الفايرستور (إذا كان نفس الجهاز الذي رفع)
          final String? firestoreLocalPath =
              requestData['localFilePath']?.toString();
          if (firestoreLocalPath != null && firestoreLocalPath.isNotEmpty) {
            List<String> fsPaths = _parseJsonList(firestoreLocalPath);
            if (fsPaths.isEmpty) fsPaths = [firestoreLocalPath];
            for (String p in fsPaths) {
              if (!pathsToDelete.contains(p)) pathsToDelete.add(p);
            }
          }

          for (String path in pathsToDelete) {
            if (path.isEmpty) continue;
            try {
              final file = File(path);
              if (file.existsSync()) {
                await file.delete();
                debugPrint('[AUTO-UPDATE] ✅ تم حذف الملف المحلي: $path');
              }
            } catch (e) {
              debugPrint('[AUTO-UPDATE] ⚠️ لم نتمكن من حذف الملف المحلي: $e');
            }
          }
        } catch (e) {
          debugPrint('[AUTO-UPDATE] ❌ خطأ أثناء تنظيف ملفات الطلب المرفوض: $e');
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في الرد على الطلب: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// مساعد لتحليل قيمة JSON وإرجاع قائمة سلاسل نصية
  List<String> _parseJsonList(dynamic value) {
    if (value == null) return [];
    final str = value.toString().trim();
    if (str.isEmpty) return [];
    if (str.startsWith('[')) {
      try {
        return List<String>.from(jsonDecode(str));
      } catch (_) {}
    }
    return [str];
  }

  /// مساعد لتحليل قيمة JSON وإرجاع خريطة مصنفة للملفات
  Map<String, List<String>> _parseJsonMap(dynamic value) {
    if (value == null) return {};
    final str = value.toString().trim();
    if (str.isEmpty) return {};
    try {
      if (str.startsWith('{')) {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        Map<String, List<String>> result = {};
        decoded.forEach((key, val) {
          result[key] = List<String>.from(val);
        });
        return result;
      } else if (str.startsWith('[')) {
        return {'others': List<String>.from(jsonDecode(str))};
      }
    } catch (_) {}
    return {
      'others': [str]
    };
  }

  Future<String?> generateLeaveRequestLocally(RequestModel req) async {
    try {
      final String requestId = req.id;
      final extraData = req.extraData;

      final applicantName =
          req.applicantName.isNotEmpty ? req.applicantName : 'غير معروف';
      final senderCollege =
          req.senderCollege.isNotEmpty ? req.senderCollege : 'غير معروف';
      final senderDepartment = extraData?['sender_department'] ?? 'غير معروف';
      final leaveType = extraData?['leave_type'] ?? 'إجازة';
      final duration =
          extraData?['duration']?.toString() ?? '....................';
      final startDate = extraData?['start_date'] != null
          ? _formatIsoDate(extraData?['start_date'])
          : '....................';
      final requestDate = extraData?['request_date'] != null
          ? _formatIsoDate(extraData?['request_date'])
          : '....................';

      final docxBytes = await DocxExportService.createLeaveRequestDocx(
        applicantName: applicantName,
        college: senderCollege,
        department: senderDepartment,
        leaveType: leaveType,
        duration: '$duration أيام',
        startDate: startDate,
        requestDate: requestDate,
        approvalHistory: extraData?['approval_history'] ?? [],
      );

      final tempDir = await getTemporaryDirectory();
      final localFile =
          File(p.join(tempDir.path, 'leave_request_$requestId.docx'));
      await localFile.writeAsBytes(docxBytes);

      debugPrint('✅ Generated leave request locally: ${localFile.path}');
      return localFile.path;
    } catch (e) {
      debugPrint('❌ Failed to generate leave request locally: $e');
      return null;
    }
  }

  Future<bool> exportLeaveRequest(RequestModel req) async {
    try {
      final extraData = req.extraData;
      final applicantName =
          req.applicantName.isNotEmpty ? req.applicantName : 'غير معروف';
      final senderCollege =
          req.senderCollege.isNotEmpty ? req.senderCollege : 'غير معروف';
      final senderDepartment = extraData?['sender_department'] ?? 'غير معروف';
      final leaveType = extraData?['leave_type'] ?? 'إجازة';
      final duration =
          extraData?['duration']?.toString() ?? '....................';
      final startDate = extraData?['start_date'] != null
          ? _formatIsoDate(extraData?['start_date'])
          : '....................';
      final requestDate = extraData?['request_date'] != null
          ? _formatIsoDate(extraData?['request_date'])
          : '....................';

      final docxBytes = await DocxExportService.createLeaveRequestDocx(
        applicantName: applicantName,
        college: senderCollege,
        department: senderDepartment,
        leaveType: leaveType,
        duration: '$duration أيام',
        startDate: startDate,
        requestDate: requestDate,
        approvalHistory: extraData?['approval_history'] ?? [],
      );

      await AppFileSaver.saveExportedFile(
        name: 'استمارة_طلب_إجازة_${applicantName.replaceAll(' ', '_')}',
        bytes: Uint8List.fromList(docxBytes),
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
      return true;
    } catch (e) {
      debugPrint('❌ Failed to export leave request: $e');
      _errorMessage = 'فشل تصدير الاستمارة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCollegeDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final colleges = await db.query('colleges');
      final departments = await db.query('departments');

      final college = colleges.firstWhere(
        (c) => c['ar_name'].toString() == _currentUserCollege,
        orElse: () => {},
      );

      if (college.isNotEmpty) {
        final collegeId = college['id'];
        _collegeDepartments = departments
            .where((d) => d['college_id'] == collegeId)
            .map((d) => d['name'].toString())
            .toList();
      } else {
        _collegeDepartments =
            departments.map((d) => d['name'].toString()).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading college departments: $e');
    }
  }

  Future<void> loadColleges() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final list = await db.query('colleges');
      _colleges = list.map((c) => c['ar_name'].toString()).toList();
      if (_colleges.isEmpty) {
        _colleges = [
          'كلية الهندسة',
          'كلية الحاسبات',
          'كلية العلوم',
          'كلية الطب',
          'كلية طب الأسنان',
          'كلية الصيدلة',
          'كلية العلوم الإدارية',
          'كلية الآداب',
          'كلية التربية',
        ];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading colleges: $e');
      _colleges = [
        'كلية الهندسة',
        'كلية الحاسبات',
        'كلية العلوم',
        'كلية الطب',
      ];
      notifyListeners();
    }
  }

  Future<void> _processAutoApprovals(
      DocumentReference requestDoc, Map<String, dynamic> requestData) async {
    try {
      final String? senderId = requestData['senderId'];
      if (senderId == null || senderId.isEmpty) return;

      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      if (!senderDoc.exists) return;

      final senderData = senderDoc.data();
      if (senderData == null) return;

      final String senderName = senderData['name'] ?? 'غير معروف';
      final String rawRole = senderData['role'] ?? '';

      List<String> senderRoles = [];
      final lowerRole = rawRole.toLowerCase();
      if (lowerRole.startsWith('[')) {
        try {
          senderRoles = List<String>.from(jsonDecode(lowerRole))
              .map((r) => r.toLowerCase())
              .toList();
        } catch (_) {}
      }
      if (senderRoles.isEmpty) {
        senderRoles = [lowerRole];
      }

      bool senderHasDeptHead = senderRoles.any((r) =>
          r.contains('dept_head') ||
          r.contains('dept head') ||
          r.contains('head of department') ||
          r.contains('رئيس قسم') ||
          r.contains('رئيس القسم'));
      bool senderHasViceDean = senderRoles.any((r) =>
          r.contains('vice_dean') ||
          r.contains('vice dean') ||
          r.contains('نائب العميد') ||
          r.contains('نائب عميد'));
      bool senderHasDean = senderRoles.any((r) =>
          (r.contains('dean') && !r.contains('vice')) || r.contains('عميد'));

      bool changed = false;
      final extraData =
          Map<String, dynamic>.from(requestData['extraData'] ?? {});
      int reqStep = extraData['current_step_order'] != null
          ? (extraData['current_step_order'] is int
              ? extraData['current_step_order'] as int
              : int.tryParse(extraData['current_step_order'].toString()) ?? 1)
          : 1;
      String status = requestData['status'] ?? 'قيد الانتظار';
      String destinationCollege = requestData['destinationCollege'] ?? '';

      List<dynamic> approvalHistory = extraData['approval_history'] != null
          ? List<dynamic>.from(extraData['approval_history'])
          : [];

      while (status == 'قيد الانتظار' && reqStep < 4) {
        bool canAutoApprove = false;
        String roleLabel = '';

        if (reqStep == 1 && senderHasDeptHead) {
          canAutoApprove = true;
          roleLabel = 'رئيس القسم (موافقة تلقائية - مقدم الطلب)';
        } else if (reqStep == 2 && senderHasViceDean) {
          canAutoApprove = true;
          roleLabel =
              'نائب العميد للشؤون الأكاديمية (موافقة تلقائية - مقدم الطلب)';
        } else if (reqStep == 3 && senderHasDean) {
          canAutoApprove = true;
          roleLabel = 'عميد الكلية (موافقة تلقائية - مقدم الطلب)';
        }

        if (canAutoApprove) {
          final alreadyApproved =
              approvalHistory.any((s) => s is Map && s['step'] == reqStep);
          if (!alreadyApproved) {
            approvalHistory.add({
              'step': reqStep,
              'approver_role': roleLabel,
              'approver_name': senderName,
              'date': DateTime.now().toIso8601String(),
            });
          }

          reqStep++;
          changed = true;

          if (reqStep == 4) {
            destinationCollege = 'نيابة الشؤون الأكاديمية';
            break;
          }
        } else {
          break;
        }
      }

      if (changed) {
        extraData['approval_history'] = approvalHistory;
        extraData['current_step_order'] = reqStep;

        await requestDoc.update({
          'extraData': extraData,
          'destinationCollege': destinationCollege,
          'status': status,
        });
      }
    } catch (e) {
      debugPrint('Error processing auto approvals: $e');
    }
  }

  bool _isSameRole(String userRoleStr, String targetRole) {
    final lowerRole = userRoleStr.toLowerCase();
    final lowerTarget = targetRole.toLowerCase();

    List<String> roles = [];
    if (lowerRole.startsWith('[')) {
      try {
        roles = List<String>.from(jsonDecode(lowerRole))
            .map((r) => r.toLowerCase())
            .toList();
      } catch (_) {}
    }
    if (roles.isEmpty) {
      roles = [lowerRole];
    }

    return roles.any((r) {
      if (r == lowerTarget) return true;
      if (lowerTarget == 'head of department' &&
          (r.contains('dept_head') ||
              r.contains('dept head') ||
              r.contains('head of department') ||
              r.contains('رئيس قسم') ||
              r.contains('رئيس القسم'))) {
        return true;
      }
      if (lowerTarget == 'vice dean for academic affairs' &&
          (r.contains('vice_dean') ||
              r.contains('vice dean') ||
              r.contains('نائب العميد') ||
              r.contains('نائب عميد'))) {
        return true;
      }
      if (lowerTarget == 'dean' &&
          ((r.contains('dean') && !r.contains('vice')) || r.contains('عميد'))) {
        return true;
      }
      return false;
    });
  }

  bool _isAcademicRole(String roleStr, String collegeStr) {
    final lowerRole = roleStr.toLowerCase();
    final lowerCollege = collegeStr.toLowerCase();

    List<String> roles = [];
    if (lowerRole.startsWith('[')) {
      try {
        roles = List<String>.from(jsonDecode(lowerRole))
            .map((r) => r.toLowerCase())
            .toList();
      } catch (_) {}
    }
    if (roles.isEmpty) {
      roles = [lowerRole];
    }

    return roles.any((r) =>
        r.contains('prosecution') ||
        r.contains('deanship') ||
        (r.contains('academic') && !r.contains('vice')) ||
        r.contains('admin') ||
        lowerCollege.contains('نيابة') ||
        lowerCollege.contains('الأكاديمية'));
  }

  Future<List<String>> _getRecipientUserIdsForRequest(RequestModel req,
      {required bool isLeaveRequest, required int step}) async {
    List<String> userIds = [];

    try {
      final snapshot = await _firestore.collection('users').get();

      if (isLeaveRequest) {
        if (step == 1) {
          final String? dept = req.extraData?['sender_department']?.toString().trim();
          final String college = req.senderCollege.trim();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userDept = data['department']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if (_isSameRole(userRole, 'Head of department') &&
                _isSameDepartment(userDept, dept ?? '') &&
                _isSameCollege(userFac, college)) {
              userIds.add(doc.id);
            }
          }
        } else if (step == 2) {
          final String college = req.senderCollege.trim();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if ((_isSameRole(userRole, 'Vice Dean for Academic Affairs') ||
                    _isSameRole(userRole, 'Vice Dean for Student Affairs')) &&
                _isSameCollege(userFac, college)) {
              userIds.add(doc.id);
            }
          }
        } else if (step == 3) {
          final String college = req.senderCollege.trim();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if (_isSameRole(userRole, 'Dean') && _isSameCollege(userFac, college)) {
              userIds.add(doc.id);
            }
          }
        } else if (step == 4) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if (_isAcademicRole(userRole, userFac)) {
              userIds.add(doc.id);
            }
          }
        }
      } else {
        final String dest = req.destinationCollege.trim();
        if (dest == 'نيابة الشؤون الأكاديمية' ||
            dest == 'جميع الكليات' ||
            dest.toLowerCase().contains('نيابة') ||
            dest.toLowerCase().contains('academic')) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if (_isAcademicRole(userRole, userFac)) {
              userIds.add(doc.id);
            }
          }
        } else {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userRole = data['role']?.toString() ?? '';
            final userFac = data['faculty']?.toString() ?? '';

            if (_isSameCollege(userFac, dest)) {
              if (_isSameRole(userRole, 'Dean') ||
                  _isSameRole(userRole, 'Vice Dean for Academic Affairs') ||
                  _isSameRole(userRole, 'Vice Dean for Student Affairs') ||
                  _isSameRole(userRole, 'Head of department')) {
                userIds.add(doc.id);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error fetching users from Firestore: $e');
    }

    return userIds.toSet().toList();
  }

  Future<void> _createNotification({
    required String userId,
    required String title,
    required String body,
    required String requestId,
    required String type,
  }) async {
    try {
      final notificationId = const Uuid().v4();
      await _firestore.collection('notifications').doc(notificationId).set({
        'id': notificationId,
        'userId': userId,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type,
        'requestId': requestId,
      });
      debugPrint('[NOTIFICATIONS] ✅ Sent notification to user: $userId (Title: $title)');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] ❌ Failed to write notification to Firestore: $e');
    }
  }

  Future<void> _sendNotificationsForRequest(RequestModel req, {required bool isNewRequest}) async {
    try {
      final String? senderId = req.senderId;
      final String status = req.status;

      // 1. إذا كان الطلب مكتملاً (مقبول أو مرفوض أو مقبول جزئياً)
      if (status == 'مقبول' || status == 'مرفوض' || status == 'مقبول جزئياً') {
        if (senderId != null && senderId.isNotEmpty) {
          final String title = status == 'مقبول'
              ? 'تم قبول طلبك'
              : (status == 'مرفوض' ? 'تم رفض طلبك' : 'تحديث بخصوص طلبك');

          String body = '';
          if (status == 'مقبول') {
            body = 'تمت الموافقة النهائية على طلبك "${req.title}".';
          } else if (status == 'مرفوض') {
            final reason = (req.rejectionReason != null && req.rejectionReason!.trim().isNotEmpty)
                ? '\nالسبب: ${req.rejectionReason}'
                : '';
            body = 'تم رفض طلبك "${req.title}".$reason';
          } else {
            body = 'تم تحديث حالة طلبك "${req.title}" إلى: $status.';
          }

          await _createNotification(
            userId: senderId,
            title: title,
            body: body,
            requestId: req.id,
            type: 'request',
          );
        }
        return;
      }

      // 2. إذا كان الطلب قيد الانتظار، نرسل للمستلمين المحددين
      if (status == 'قيد الانتظار') {
        final bool isLeave = req.type == 'استمارة طلب إجازة' || req.type.contains('إجازة');
        final int step = req.extraData?['current_step_order'] != null
            ? (req.extraData!['current_step_order'] is int
                ? req.extraData!['current_step_order'] as int
                : int.tryParse(req.extraData!['current_step_order'].toString()) ?? 1)
            : 1;

        final List<String> recipients = await _getRecipientUserIdsForRequest(req, isLeaveRequest: isLeave, step: step);

        String title = 'طلب جديد وارد';
        String body = 'تم إرسال طلب جديد "${req.title}" من ${req.applicantName}.';

        if (isLeave) {
          String stepLabel = 'رئيس القسم';
          if (step == 2) stepLabel = 'نائب العميد للشؤون الأكاديمية';
          if (step == 3) stepLabel = 'عميد الكلية';
          if (step == 4) stepLabel = 'نيابة الشؤون الأكاديمية';

          title = 'طلب إجازة جديد بانتظار موافقتك';
          body = 'طلب إجازة مقدم من ${req.applicantName} بانتظار موافقتك بصفتك $stepLabel.';
        }

        for (var userId in recipients) {
          if (userId == _currentUserId) continue;

          await _createNotification(
            userId: userId,
            title: title,
            body: body,
            requestId: req.id,
            type: 'request',
          );
        }
      }
    } catch (e) {
      debugPrint('[NOTIFICATIONS] ❌ فشل إرسال الإشعارات: $e');
    }
  }
}
