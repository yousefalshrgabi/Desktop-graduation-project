import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:uuid/uuid.dart';
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
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = const Uuid().v4();
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
      );

      await _firestore
          .collection('meetings')
          .doc(id)
          .set(newMeeting.toMap());

      // كتابة مستندات إشعار لكل حاضر في Firestore
      for (final attendeeId in attendeeIds) {
        if (attendeeId.isNotEmpty) {
          final notificationId = const Uuid().v4();
          await _firestore.collection('notifications').doc(notificationId).set({
            'id': notificationId,
            'userId': attendeeId,
            'title': 'اجتماع مجلس قسم جديد',
            'body': 'تمت جدولة اجتماع جديد بعنوان: "$title" بتاريخ $date الساعة $time في قاعة: "$room".',
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
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('meetings').doc(meetingId).update({
        'title': title,
        'date': date,
        'time': time,
        'room': room,
        'agenda': agenda,
        'attendees': attendees,
        'attendeeIds': attendeeIds,
      });

      // كتابة إشعارات التعديل لكل الحاضرين في Firestore
      for (final attendeeId in attendeeIds) {
        if (attendeeId.isNotEmpty) {
          final notificationId = const Uuid().v4();
          await _firestore.collection('notifications').doc(notificationId).set({
            'id': notificationId,
            'userId': attendeeId,
            'title': 'تعديل موعد اجتماع مجلس القسم',
            'body': 'تم تعديل موعد اجتماع "$title" ليصبح بتاريخ $date الساعة $time في قاعة: "$room".',
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

      // إرسال إشعارات الإلغاء لجميع الحاضرين المسجلين
      for (final attendeeId in meeting.attendeeIds) {
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
      if (!await hasInternet()) {
        throw Exception('لا يوجد اتصال بالإنترنت للرفع إلى الخادم.');
      }

      final cleanName = file.name.replaceAll(' ', '_');
      final storagePath = 'meetings/${meeting.departmentId}/${meeting.id}_$cleanName';
      
      debugPrint('[STORAGE UPLOAD] Target Path: $storagePath');
      final storageRef = _storage.ref().child(storagePath);

      // قراءة بايتات الملف بأمان (تجنباً لمشاكل مسارات ويندوز مع الحروف العربية)
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('ملف فارغ أو غير متاح.');
      }

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
      debugPrint('[STORAGE UPLOAD ERROR] Exception occurred during upload: $e');
      debugPrint('[STORAGE UPLOAD ERROR] StackTrace: $stackTrace');
      _errorMessage = 'حدث خطأ أثناء رفع وتوثيق المحضر: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
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
