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

  StreamSubscription? _receivedSubscription;
  StreamSubscription? _sentSubscription;

  RequestViewModel() {
    _loadCurrentUser();
  }

  bool _isManualMode = false;

  void setUserData({required String name, required String college, required String role}) {
    _isManualMode = true;
    _currentUserName = name;
    _currentUserCollege = college;
    _currentUserRole = role;
    startListening();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isManualMode) return;

    _currentUserRole = prefs.getString('userRole') ?? 'Admin';
    _currentUserName = prefs.getString('userName') ?? 'المدير العام';
    _currentUserCollege = prefs.getString('college') ?? 'نيابة الشؤون الأكاديمية';
    
    startListening();
  }

  void startListening() {
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();

    _isLoading = true;
    notifyListeners();

    Query queryReceived;
    if (_currentUserRole == 'Admin' || _currentUserCollege == 'نيابة الشؤون الأكاديمية') {
      queryReceived = _firestore
          .collection('requests')
          .where('destinationCollege', whereIn: ['نيابة الشؤون الأكاديمية', 'جميع الكليات'])
          .orderBy('dateSent', descending: true);
    } else {
      queryReceived = _firestore
          .collection('requests')
          .where('destinationCollege', isEqualTo: _currentUserCollege)
          .orderBy('dateSent', descending: true);
    }

    _receivedSubscription = queryReceived.snapshots().listen((snapshot) async {
      _receivedRequests = snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // حفظ في القاعدة المحلية للمزامنة مستقبلاً
      for (var req in _receivedRequests) {
        final data = req.toMap();
        data['id'] = req.id;
        data['dateSent'] = req.dateSent.toIso8601String();
        await DatabaseHelper.instance.insertRequestLocal(data);
      }

      _isLoading = false;
      notifyListeners();
    }, onError: (e) async {
      debugPrint('خطأ في جلب الطلبات الواردة (ربما بسبب الأوفلاين): $e');
      // محاولة التحميل من القاعدة المحلية
      await _loadLocalRequests();
      _isLoading = false;
      notifyListeners();
    });

    _sentSubscription = _firestore
        .collection('requests')
        .where('senderCollege', isEqualTo: _currentUserCollege)
        .orderBy('dateSent', descending: true)
        .snapshots()
        .listen((snapshot) async {
      _sentRequests = snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // حفظ محلي للمزامنة
      for (var req in _sentRequests) {
        final data = req.toMap();
        data['id'] = req.id;
        data['dateSent'] = req.dateSent.toIso8601String();
        await DatabaseHelper.instance.insertRequestLocal(data);
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('خطأ في جلب الطلبات الصادرة: $e');
    });
  }

  Future<void> _loadLocalRequests() async {
    final localData = await DatabaseHelper.instance.getLocalRequests();
    if (localData.isNotEmpty) {
      // تصفية الطلبات الواردة والصادرة محلياً
      final allLocal = localData.map((map) => RequestModel.fromMap(map, map['id'])).toList();
      
      if (_currentUserRole == 'Admin') {
        _receivedRequests = allLocal.where((r) => 
          ['نيابة الشؤون الأكاديمية', 'جميع الكليات'].contains(r.destinationCollege)).toList();
      } else {
        _receivedRequests = allLocal.where((r) => r.destinationCollege == _currentUserCollege).toList();
      }
      
      _sentRequests = allLocal.where((r) => r.senderCollege == _currentUserCollege).toList();
    }
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _sentSubscription?.cancel();
    super.dispose();
  }

  Future<void> refreshRequests() async {
    startListening();
  }

  // دالة لاختيار ملف من الجهاز
  Future<PlatformFile?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
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

  // دالة لرفع الملف إلى Firebase Storage
  Future<String?> _uploadFile(PlatformFile file) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      Reference ref = _storage.ref().child('request_files/$fileName');
      
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

  // دالة لحفظ الملف محلياً للأرشفة والوصول بدون إنترنت
  Future<String?> _saveFileLocally(PlatformFile file) async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final archiveDir = Directory(p.join(directory.path, 'archived_requests'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final localPath = p.join(archiveDir.path, fileName);

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

  // دالة لتحميل الملف من Firebase وحفظه محلياً
  Future<String?> downloadFile(RequestModel request) async {
    if (request.fileUrl == null || request.fileUrl!.isEmpty) return null;
    
    try {
      _isLoading = true; // يمكننا استخدام مؤشر التحميل العام أو مؤشر خاص
      notifyListeners();

      final directory = await getApplicationDocumentsDirectory();
      final archiveDir = Directory(p.join(directory.path, 'archived_requests'));
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }

      // توليد اسم للملف
      String fileName = 'downloaded_${DateTime.now().millisecondsSinceEpoch}_' + 
                        p.basename(Uri.parse(request.fileUrl!).path);
      
      final localPath = p.join(archiveDir.path, fileName);
      final File file = File(localPath);

      // التحميل من Firebase Storage
      await _storage.refFromURL(request.fileUrl!).writeToFile(file);
      
      // تحديث القاعدة المحلية بالمسار الجديد
      await DatabaseHelper.instance.updateRequestLocalPath(request.id, localPath);
      
      _isLoading = false;
      notifyListeners();
      return localPath;
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
    PlatformFile? attachedFile,
    String? applicantName,
    String? senderCollege,
  }) async {
    _isSending = true;
    _errorMessage = '';
    notifyListeners();

    try {
      String? fileUrl;
      String? localFilePath;

      if (attachedFile != null) {
        // 1. حفظ محلي للأرشفة
        localFilePath = await _saveFileLocally(attachedFile);
        
        // 2. رفع للسحابة
        fileUrl = await _uploadFile(attachedFile);
        
        if (fileUrl == null) {
          _isSending = false;
          notifyListeners();
          return false;
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
        fileUrl: fileUrl,
        localFilePath: localFilePath,
      );

      // حفظ في Firestore
      await _firestore.collection('requests').add(newRequest.toMap());
      
      // ملاحظة: لا نحتاج لإضافة الطلب يدوياً للقائمة لأن الـ StreamSubscription 
      // سيقوم بالتقاط التغيير من Firestore وتحديث الواجهة تلقائياً في كلا الجهازين.

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

  Future<bool> respondToRequest(String requestId, String status, {String? rejectionReason}) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': status,
        'rejectionReason': rejectionReason,
        'dateReplied': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _errorMessage = 'فشل في الرد على الطلب: $e';
      notifyListeners();
      return false;
    }
  }
}
