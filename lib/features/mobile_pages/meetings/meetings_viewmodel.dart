import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/services/docx_export_service.dart';
import 'meeting_model.dart';

class MeetingsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AppSession _session = AppSession();

  List<MeetingModel> _meetings = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<MeetingModel> get meetings => _meetings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // تصفية الاجتماعات بناءً على الدور والقسم
  List<MeetingModel> get filteredMeetings {
    final deptId = _session.userDepartment;
    final college = _session.userCollege;

    if (_session.isDeptHead) {
      return _meetings.where((m) => m.departmentId == deptId).toList();
    } else if (_session.isViceDean) {
      // نائب العميد يرى الاجتماعات التي تنتظر موافقته، وتلك المعتمدة/المحالة مسبقاً
      return _meetings.where((m) =>
          m.college == college &&
          m.status != MeetingStatus.scheduled &&
          m.status != MeetingStatus.draft).toList();
    } else if (_session.isDean) {
      // العميد يرى الاجتماعات المعتمدة من نائب العميد، أو المعتمدة نهائياً، أو المرفوضة
      return _meetings.where((m) =>
          m.college == college &&
          (m.status == MeetingStatus.pendingDean ||
           m.status == MeetingStatus.forwardedToPresidency ||
           m.status == MeetingStatus.rejected)).toList();
    }
    return [];
  }

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // تحميل كافة الاجتماعات من Firestore
  Future<void> loadMeetings() async {
    // محاولة رفع الملفات المعلقة في الخلفية عند تحديث الصفحة أو فتحها
    checkAndUploadPendingFiles();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[MEETINGS DEBUG] 🟢 1. Starting Firestore collection get() query...');
      final snapshot = await _firestore
          .collection('meetings')
          .get()
          .timeout(const Duration(seconds: 6));
      debugPrint('[MEETINGS DEBUG] 🟢 2. Query completed. Received ${snapshot.docs.length} documents.');

      final list = snapshot.docs
          .map((doc) {
            debugPrint('[MEETINGS DEBUG] 📦 Parsing document ID: ${doc.id}');
            return MeetingModel.fromMap(doc.data());
          })
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _meetings = list;
      debugPrint('[MEETINGS DEBUG] 🟢 3. In-memory sorting finished. Loaded ${_meetings.length} meetings.');
    } catch (e) {
      debugPrint('[MEETINGS DEBUG] ❌ Error loading meetings: $e');
      _errorMessage = 'حدث خطأ أثناء تحميل الاجتماعات: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // جدولة اجتماع جديد
  Future<bool> scheduleMeeting({
    required String title,
    required String date,
    required String time,
    required String room,
    required List<String> agenda,
    required List<String> attendees,
    required List<String> attendeeIds,
    PlatformFile? previousMinutesFile,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = const Uuid().v4();
      String? previousMinutesUrl;
      String? previousMinutesName;

      if (previousMinutesFile != null) {
        if (!await hasInternet()) {
          throw Exception('لا يوجد اتصال بالإنترنت للرفع إلى الخادم.');
        }
        final cleanName = previousMinutesFile.name.replaceAll(' ', '_');
        final deptId = _session.userDepartment;
        final storagePath = 'meetings/$deptId/previous_minutes_${id}_$cleanName';
        
        debugPrint('[STORAGE UPLOAD] Previous Minutes Path: $storagePath');
        final storageRef = _storage.ref().child(storagePath);

        Uint8List bytes;
        if (previousMinutesFile.bytes != null) {
          bytes = previousMinutesFile.bytes!;
        } else if (previousMinutesFile.path != null) {
          bytes = await File(previousMinutesFile.path!).readAsBytes();
        } else {
          throw Exception('ملف فارغ أو غير متاح.');
        }

        final uploadTask = storageRef.putData(bytes);
        final snapshot = await uploadTask;
        previousMinutesUrl = await snapshot.ref.getDownloadURL();
        previousMinutesName = previousMinutesFile.name;
      }

      final newMeeting = MeetingModel(
        id: id,
        title: title,
        date: date,
        time: time,
        room: room,
        agenda: agenda,
        attendees: attendees,
        attendeeIds: attendeeIds,
        minutes: '',
        status: MeetingStatus.scheduled,
        departmentId: _session.userDepartment,
        college: _session.userCollege,
        createdAt: DateTime.now(),
        previousMinutesUrl: previousMinutesUrl,
        previousMinutesName: previousMinutesName,
      );

      await _firestore
          .collection('meetings')
          .doc(id)
          .set(newMeeting.toMap());

      // كتابة مستندات إشعار لكل حاضر ومنشئ الاجتماع في Firestore
      final Set<String> notificationReceivers = Set.from(attendeeIds);
      if (_session.userId.isNotEmpty) {
        notificationReceivers.add(_session.userId); // لكي يظهر الإشعار لك عند الاختبار
      }

      for (final attendeeId in notificationReceivers) {
        if (attendeeId.isNotEmpty) {
          final notificationId = const Uuid().v4();
          await _firestore.collection('notifications').doc(notificationId).set({
            'id': notificationId,
            'userId': attendeeId,
            'title': 'اجتماع مجلس قسم جديد',
            'body': 'تمت جدولة اجتماع جديد بعنوان: "$title" بتاريخ $date الساعة $time في قاعة: "$room".${previousMinutesUrl != null ? ' (تم إرفاق محضر الاجتماع السابق)' : ''}',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'meeting',
            'meetingId': id,
          });
          debugPrint('[NOTIFICATIONS] Sent meeting notification to user: $attendeeId');
        }
      }

      await loadMeetings(); // تحديث القائمة
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء جدولة الاجتماع: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // تعديل تفاصيل اجتماع قائم وتجديد الإشعارات للحاضرين
  Future<bool> updateMeeting({
    required String meetingId,
    required String title,
    required String date,
    required String time,
    required String room,
    required List<String> agenda,
    required List<String> attendees,
    required List<String> attendeeIds,
    PlatformFile? previousMinutesFile,
    String? existingPreviousMinutesUrl,
    String? existingPreviousMinutesName,
    bool clearPreviousMinutes = false,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? previousMinutesUrl = existingPreviousMinutesUrl;
      String? previousMinutesName = existingPreviousMinutesName;

      if (clearPreviousMinutes) {
        previousMinutesUrl = null;
        previousMinutesName = null;
      } else if (previousMinutesFile != null) {
        if (!await hasInternet()) {
          throw Exception('لا يوجد اتصال بالإنترنت للرفع إلى الخادم.');
        }
        final cleanName = previousMinutesFile.name.replaceAll(' ', '_');
        final deptId = _session.userDepartment;
        final storagePath = 'meetings/$deptId/previous_minutes_${meetingId}_$cleanName';
        
        debugPrint('[STORAGE UPLOAD] Previous Minutes Path: $storagePath');
        final storageRef = _storage.ref().child(storagePath);

        Uint8List bytes;
        if (previousMinutesFile.bytes != null) {
          bytes = previousMinutesFile.bytes!;
        } else if (previousMinutesFile.path != null) {
          bytes = await File(previousMinutesFile.path!).readAsBytes();
        } else {
          throw Exception('ملف فارغ أو غير متاح.');
        }

        final uploadTask = storageRef.putData(bytes);
        final snapshot = await uploadTask;
        previousMinutesUrl = await snapshot.ref.getDownloadURL();
        previousMinutesName = previousMinutesFile.name;
      }

      await _firestore.collection('meetings').doc(meetingId).update({
        'title': title,
        'date': date,
        'time': time,
        'room': room,
        'agenda': agenda,
        'attendees': attendees,
        'attendeeIds': attendeeIds,
        'previousMinutesUrl': previousMinutesUrl,
        'previousMinutesName': previousMinutesName,
      });

      // كتابة إشعارات التعديل لكل الحاضرين ومنشئ الاجتماع في Firestore
      final Set<String> notificationReceivers = Set.from(attendeeIds);
      if (_session.userId.isNotEmpty) {
        notificationReceivers.add(_session.userId);
      }

      for (final attendeeId in notificationReceivers) {
        if (attendeeId.isNotEmpty) {
          final notificationId = const Uuid().v4();
          await _firestore.collection('notifications').doc(notificationId).set({
            'id': notificationId,
            'userId': attendeeId,
            'title': 'تعديل موعد اجتماع مجلس القسم',
            'body': 'تم تعديل موعد اجتماع "$title" ليصبح بتاريخ $date الساعة $time في قاعة: "$room".${previousMinutesUrl != null ? ' (تم إرفاق محضر الاجتماع السابق)' : ''}',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'meeting',
            'meetingId': meetingId,
          });
        }
      }

      await loadMeetings(); // تحديث القائمة
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تعديل الاجتماع: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // إلغاء اجتماع قائم وإرسال إشعارات الإلغاء
  Future<bool> cancelMeeting(MeetingModel meeting) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('meetings').doc(meeting.id).update({
        'status': MeetingStatus.canceled.key,
      });

      // إرسال إشعارات الإلغاء لجميع الحاضرين المسجلين ومنشئ الاجتماع
      final Set<String> notificationReceivers = Set.from(meeting.attendeeIds);
      if (_session.userId.isNotEmpty) {
        notificationReceivers.add(_session.userId);
      }

      for (final attendeeId in notificationReceivers) {
        if (attendeeId.isNotEmpty) {
          final notificationId = const Uuid().v4();
          await _firestore.collection('notifications').doc(notificationId).set({
            'id': notificationId,
            'userId': attendeeId,
            'title': 'إلغاء اجتماع مجلس القسم',
            'body': 'تم إلغاء الاجتماع الذي كان مقرراً بعنوان: "${meeting.title}" بتاريخ ${meeting.date}.',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'meeting',
            'meetingId': meeting.id,
          });
        }
      }

      await loadMeetings(); // تحديث القائمة
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء إلغاء الاجتماع: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // حفظ مسودة المحضر في Firestore
  Future<bool> saveMinutesDraft(String meetingId, String minutesText) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('meetings').doc(meetingId).update({
        'minutes': minutesText,
        'status': MeetingStatus.draft.key,
      });

      await loadMeetings();
      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء حفظ المسودة: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // توليد وتصدير المحضر كملف .docx محلياً باستخدام FileSaver
  Future<bool> exportMinutesToDocx(MeetingModel meeting, String minutesText) async {
    try {
      final docxBytes = DocxExportService.createDocx(
        title: meeting.title,
        date: meeting.date,
        time: meeting.time,
        agenda: meeting.agenda,
        attendees: meeting.attendees,
        minutes: minutesText,
      );

      final cleanTitle = meeting.title.replaceAll(' ', '_');
      final fileName = '${meeting.id}_$cleanTitle';

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(docxBytes),
        fileExtension: 'docx',
        mimeType: MimeType.other, // ملفات Word أو غيرها
      );

      return true;
    } catch (e) {
      _errorMessage = 'فشل تصدير ملف Word: $e';
      notifyListeners();
      return false;
    }
  }

  // رفع ملف المحضر وتمريره لاعتماد نائب العميد
  Future<bool> uploadAndSubmitMinutes({
    required MeetingModel meeting,
    required PlatformFile file,
    required String minutesText,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // قراءة بايتات الملف بأمان (تجنباً لمشاكل مسارات ويندوز مع الحروف العربية)
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('ملف فارغ أو غير متاح.');
      }

      final cleanName = file.name.replaceAll(' ', '_');

      if (!await hasInternet()) {
        // [حالة عدم توفر إنترنت]: نقوم بحفظ الملف محلياً وتخزينه في قائمة الانتظار للمزامنة لاحقاً
        debugPrint('[OFFLINE DETECTED] Saving minutes and file locally for meeting: ${meeting.id}');
        
        final appDir = await getApplicationDocumentsDirectory();
        final pendingDir = Directory('${appDir.path}/pending_uploads');
        if (!await pendingDir.exists()) {
          await pendingDir.create(recursive: true);
        }

        final localFilePath = '${pendingDir.path}/${meeting.id}_$cleanName';
        final localFile = File(localFilePath);
        await localFile.writeAsBytes(bytes);

        // تخزين البيانات الوصفية في SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final List<String> pendingList = prefs.getStringList('pending_docx_uploads') ?? [];
        
        // التنسيق: meetingId|departmentId|fileName|localFilePath|minutesText
        final metadata = '${meeting.id}|${meeting.departmentId}|${file.name}|$localFilePath|${minutesText.replaceAll('\n', '\\n')}';
        pendingList.add(metadata);
        await prefs.setStringList('pending_docx_uploads', pendingList);

        // تحديث حالة الاجتماع في Firestore محلياً (المزامنة غير المتصلة لـ Firestore ستتكفل بتحديث النصوص)
        await _firestore.collection('meetings').doc(meeting.id).update({
          'minutes': minutesText,
          'documentUrl': 'local_pending_upload', // مؤشر على أن الملف ينتظر الرفع
          'status': MeetingStatus.pendingViceDean.key,
          'rejectReason': null,
        });

        debugPrint('[OFFLINE SUCCESS] Meeting updated locally. Will upload file once internet is available.');
        await loadMeetings();
        return true;
      }

      // [حالة توفر إنترنت]: الرفع المباشر
      final storagePath = 'meetings/${meeting.departmentId}/${meeting.id}_$cleanName';
      debugPrint('[STORAGE UPLOAD] Target Path: $storagePath');
      final storageRef = _storage.ref().child(storagePath);

      debugPrint('[STORAGE UPLOAD] File Size: ${bytes.length} bytes. Starting uploadTask...');

      // الرفع إلى التخزين السحابي Cloud Storage
      final uploadTask = storageRef.putData(bytes);
      final snapshot = await uploadTask;
      final documentUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('[STORAGE UPLOAD] Success! Download URL: $documentUrl');

      // التحديث في Firestore: تعيين الحالة إلى في انتظار نائب العميد
      await _firestore.collection('meetings').doc(meeting.id).update({
        'minutes': minutesText,
        'documentUrl': documentUrl,
        'status': MeetingStatus.pendingViceDean.key,
        'rejectReason': null,
      });

      await loadMeetings();
      return true;
    } catch (e, stackTrace) {
      debugPrint('[STORAGE UPLOAD ERROR] Exception occurred: $e');
      debugPrint('[STORAGE UPLOAD ERROR] StackTrace: $stackTrace');
      _errorMessage = 'حدث خطأ أثناء حفظ وتوثيق المحضر: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // مراجعة ورفع الملفات المعلقة التي تم حفظها محلياً عند انقطاع الإنترنت تلقائياً
  Future<void> checkAndUploadPendingFiles() async {
    if (!await hasInternet()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pendingList = prefs.getStringList('pending_docx_uploads') ?? [];
      if (pendingList.isEmpty) return;

      debugPrint('[OFFLINE SYNC] Found ${pendingList.length} pending uploads. Starting sync...');
      final List<String> remainingList = [];

      for (final item in pendingList) {
        final parts = item.split('|');
        if (parts.length < 5) continue;

        final meetingId = parts[0];
        final departmentId = parts[1];
        final fileName = parts[2];
        final localPath = parts[3];
        final minutesText = parts[4].replaceAll('\\n', '\n');

        final localFile = File(localPath);
        if (!await localFile.exists()) {
          debugPrint('[OFFLINE SYNC] Local file not found: $localPath, skipping.');
          continue;
        }

        try {
          final cleanName = fileName.replaceAll(' ', '_');
          final storagePath = 'meetings/$departmentId/${meetingId}_$cleanName';
          final storageRef = _storage.ref().child(storagePath);

          final bytes = await localFile.readAsBytes();
          debugPrint('[OFFLINE SYNC] Uploading $fileName for meeting $meetingId...');
          final uploadTask = storageRef.putData(bytes);
          final snapshot = await uploadTask;
          final documentUrl = await snapshot.ref.getDownloadURL();

          // تحديث مستند Firestore بالرابط السحابي
          await _firestore.collection('meetings').doc(meetingId).update({
            'documentUrl': documentUrl,
          });

          debugPrint('[OFFLINE SYNC] Upload successful for $meetingId. Deleting local temp file...');
          await localFile.delete();
        } catch (e) {
          debugPrint('[OFFLINE SYNC] Failed to sync meeting $meetingId: $e');
          remainingList.add(item);
        }
      }

      await prefs.setStringList('pending_docx_uploads', remainingList);
      if (remainingList.isEmpty) {
        debugPrint('[OFFLINE SYNC] All pending files synced successfully!');
      }
    } catch (e) {
      debugPrint('[OFFLINE SYNC ERROR] Error during sync: $e');
    }
  }

  // اعتماد محضر الاجتماع (نائب العميد -> العميد، والعميد -> محال إلى رئاسة الجامعة)
  Future<bool> approveMeeting(MeetingModel meeting) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      MeetingStatus nextStatus;

      if (_session.isViceDean) {
        nextStatus = MeetingStatus.pendingDean;
      } else if (_session.isDean) {
        nextStatus = MeetingStatus.forwardedToPresidency;
      } else {
        throw Exception('غير مصرح لك باتخاذ هذا القرار.');
      }

      await _firestore.collection('meetings').doc(meeting.id).update({
        'status': nextStatus.key,
        'rejectReason': null,
      });

      await loadMeetings();
      return true;
    } catch (e) {
      _errorMessage = 'فشلت عملية الموافقة: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // رفض محضر الاجتماع مع ذكر السبب
  Future<bool> rejectMeeting(MeetingModel meeting, String reason) async {
    if (reason.trim().isEmpty) {
      _errorMessage = 'يرجى كتابة سبب الرفض/طلب التعديل.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('meetings').doc(meeting.id).update({
        'status': MeetingStatus.rejected.key,
        'rejectReason': reason,
      });

      await loadMeetings();
      return true;
    } catch (e) {
      _errorMessage = 'فشلت عملية الرفض: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
