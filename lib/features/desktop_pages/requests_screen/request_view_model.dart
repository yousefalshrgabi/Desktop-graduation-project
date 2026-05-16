import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
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

  void setUserData(
      {required String name,
      required String college,
      required String role,
      String? userId}) {
    _isManualMode = true;
    _currentUserName = name;
    _currentUserCollege = college;
    _currentUserRole = role;
    _currentUserId = userId;
    startListening();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isManualMode) return;

    _currentUserRole = prefs.getString('userRole') ?? 'Admin';
    _currentUserName = prefs.getString('userName') ?? 'المدير العام';
    _currentUserCollege =
        prefs.getString('college') ?? 'نيابة الشؤون الأكاديمية';
    _currentUserId = prefs.getString('userId') ?? '';

    startListening();
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
        role.contains('academic') ||
        college.contains('نيابة') ||
        college.contains('الأكاديمية')) {
      queryReceived = _firestore.collection('requests').where(
          'destinationCollege',
          whereIn: ['نيابة الشؤون الأكاديمية', 'جميع الكليات']);
    } else {
      queryReceived = _firestore
          .collection('requests')
          .where('destinationCollege', isEqualTo: _currentUserCollege);
    }

    _receivedSubscription = queryReceived
        .snapshots() // أزلنا orderBy من الاستعلام لتجنب مشاكل الـ Index
        .listen((snapshot) async {
      _receivedRequests = snapshot.docs
          .map((doc) =>
              RequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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

      String role = (_currentUserRole ?? '').toLowerCase();
      String college = (_currentUserCollege ?? '');

      if (role.contains('admin') ||
          role.contains('prosecution') ||
          role.contains('deanship') ||
          role.contains('academic') ||
          college.contains('نيابة')) {
        _receivedRequests = allLocal
            .where((r) => ['نيابة الشؤون الأكاديمية', 'جميع الكليات']
                .contains(r.destinationCollege))
            .toList();
      } else {
        _receivedRequests = allLocal
            .where((r) => r.destinationCollege == _currentUserCollege)
            .toList();
      }

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

  /// رفع الملف مباشرة إلى مجلد العضو في Firebase Storage
  Future<String?> _uploadFile(PlatformFile file, String memberName) async {
    try {
      String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      Reference ref =
          _storage.ref().child('faculty_files/$cleanName/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(file.bytes!);
      } else {
        uploadTask = ref.putFile(File(file.path!));
      }

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
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

  Future<String?> downloadFile(RequestModel request) async {
    if (request.fileUrl == null || request.fileUrl!.isEmpty) return null;

    try {
      _isLoading = true;
      notifyListeners();

      final directory = await getApplicationDocumentsDirectory();
      final archiveDir = Directory(p.join(directory.path, 'archived_requests'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }

      List<String> urls = [];
      if (request.fileUrl!.startsWith('[')) {
        urls = List<String>.from(jsonDecode(request.fileUrl!));
      } else {
        urls = [request.fileUrl!];
      }

      List<String> localPaths = [];
      for (int i = 0; i < urls.length; i++) {
        String url = urls[i];
        String fileName =
            'downloaded_${DateTime.now().millisecondsSinceEpoch}_${i}_' +
                p.basename(Uri.parse(url).path);
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
      return localPaths
          .first; // نرجع المسار الأول للتوافق مع دالة الفتح البسيطة
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

      await _firestore.collection('requests').add(newRequest.toMap());

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
      {String? rejectionReason}) async {
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

      // 2. تحديث حالة الطلب في السحابة
      await _firestore.collection('requests').doc(requestId).update({
        'status': status,
        'rejectionReason': rejectionReason,
        'dateReplied': FieldValue.serverTimestamp(),
      });

      // 3. التحديث التلقائي لبيانات العضو عند الموافقة
      if (status == 'مقبول' && type == 'تعديل معلومات' && senderId != null) {
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
            'universityAppointmentDate': 'university_appointment_date',
            'bscDegree': 'bsc_degree',
            'mscDegree': 'msc_degree',
            'currentDegree': 'current_degree',
            'exactSpecialization': 'exact_specialization',
            'currentAcademicTitle': 'current_academic_title',
          };

          extraData?.forEach((key, value) {
            if (key == 'name' || key == 'department' || key == 'idCardNumber') {
              userData[key] = value;
            }
            facultyData[keyMap[key] ?? key] = value;
          });

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
            // fallback: ابحث في SQLite المحلي
            final db = await DatabaseHelper.instance.database;
            final localRecord = await db.query('faculty_members',
                where: 'user_id = ?', whereArgs: [senderId], limit: 1);
            if (localRecord.isNotEmpty) {
              currentMember = Map<String, dynamic>.from(localRecord.first);
              facultyDocId = currentMember['id']?.toString();
            }
          }

          if (facultyDocId == null || currentMember.isEmpty) {
            debugPrint(
                '[AUTO-UPDATE] ⚠️ لم يتم العثور على سجل العضو: $senderId');
          } else {
            // معالجة الملفات المرفقة في الطلب
            final String? reqFileUrl = requestData['fileUrl']?.toString();

            if (reqFileUrl != null && reqFileUrl.isNotEmpty) {
              // القوائم الحالية للعضو
              List<String> currentUrls =
                  _parseJsonList(currentMember['file_url']);
              List<String> currentLocalPaths =
                  _parseJsonList(currentMember['local_file_path']);

              // الروابط الجديدة من الطلب (مرفوعة مسبقاً إلى faculty_files/{name}/)
              List<String> newUrls = _parseJsonList(reqFileUrl);
              if (newUrls.isEmpty && reqFileUrl.isNotEmpty)
                newUrls = [reqFileUrl];

              // المسارات المحلية من الطلب (محفوظة مسبقاً في AcademicAffairs/FacultyFiles/{name}/)
              String? reqLocalPath = requestData['localFilePath']?.toString();
              List<String> newLocalPaths =
                  reqLocalPath != null ? _parseJsonList(reqLocalPath) : [];

              // إضافة الملفات الجديدة للقوائم الحالية للعضو بدون إعادة رفع
              for (int i = 0; i < newUrls.length; i++) {
                String url = newUrls[i];
                if (url.isEmpty) continue;
                String localPath =
                    i < newLocalPaths.length ? newLocalPaths[i] : '';

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

                currentUrls.add(url);
                currentLocalPaths.add(localPath);
              }

              facultyData['file_url'] = jsonEncode(currentUrls);
              facultyData['local_file_path'] = jsonEncode(currentLocalPaths);
              debugPrint(
                  '[AUTO-UPDATE] 📁 إجمالي ملفات العضو: ${currentUrls.length}');
            }

            // تحديث SQLite وFirestore
            if (facultyData.isNotEmpty) {
              await DatabaseHelper.instance.updateRecordLocal(
                  'faculty_members', senderId, facultyData,
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
          if (userData.isNotEmpty) {
            await DatabaseHelper.instance.updateRecordLocal(
                'users', senderId, userData,
                whereColumn: 'id');
            await _firestore
                .collection('users')
                .doc(senderId)
                .set(userData, SetOptions(merge: true));
          }

          debugPrint('[AUTO-UPDATE] ✅ اكتملت عملية التحديث التلقائي.');
        } catch (e) {
          debugPrint('[AUTO-UPDATE] ❌ فشل التحديث التلقائي: $e');
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
}
