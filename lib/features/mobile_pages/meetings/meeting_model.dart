import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingStatus {
  scheduled,
  draft,
  pendingViceDean,
  pendingDean,
  forwardedToPresidency,
  rejected,
  canceled, // حالة إلغاء الاجتماع
}

extension MeetingStatusExtension on MeetingStatus {
  String get key {
    switch (this) {
      case MeetingStatus.scheduled:
        return 'scheduled';
      case MeetingStatus.draft:
        return 'draft';
      case MeetingStatus.pendingViceDean:
        return 'pending_vice_dean';
      case MeetingStatus.pendingDean:
        return 'pending_dean';
      case MeetingStatus.forwardedToPresidency:
        return 'forwarded_to_presidency';
      case MeetingStatus.rejected:
        return 'rejected';
      case MeetingStatus.canceled:
        return 'canceled';
    }
  }

  String get displayName {
    switch (this) {
      case MeetingStatus.scheduled:
        return 'مجدول';
      case MeetingStatus.draft:
        return 'مسودة المحضر';
      case MeetingStatus.pendingViceDean:
        return 'قيد مراجعة نائب العميد';
      case MeetingStatus.pendingDean:
        return 'قيد مراجعة العميد';
      case MeetingStatus.forwardedToPresidency:
        return 'مكتمل (مرسل للنيابة)';
      case MeetingStatus.rejected:
        return 'مرفوض / يحتاج تعديل';
      case MeetingStatus.canceled:
        return 'ملغي';
    }
  }
}

class MeetingModel {
  final String id;
  final String title;
  final String date;
  final String time;
  final String room; // تحديد قاعة الاجتماع
  final List<String> agenda;
  final List<String> attendees;
  final List<String> attendeeIds; // معرفات الحاضرين للإشعارات
  final String minutes;
  final String? documentUrl;
  final MeetingStatus status;
  final String departmentId;
  final String college;
  final DateTime createdAt;
  final String? rejectReason;
  final String? previousMinutesUrl;
  final String? previousMinutesName;

  MeetingModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.room,
    required this.agenda,
    required this.attendees,
    required this.attendeeIds,
    required this.minutes,
    this.documentUrl,
    required this.status,
    required this.departmentId,
    required this.college,
    required this.createdAt,
    this.rejectReason,
    this.previousMinutesUrl,
    this.previousMinutesName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'room': room,
      'agenda': agenda,
      'attendees': attendees,
      'attendeeIds': attendeeIds,
      'minutes': minutes,
      'documentUrl': documentUrl,
      'status': status.key,
      'departmentId': departmentId,
      'college': college,
      'createdAt': createdAt.toIso8601String(),
      'rejectReason': rejectReason,
      'previousMinutesUrl': previousMinutesUrl,
      'previousMinutesName': previousMinutesName,
    };
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      return DateTime.tryParse(val) ?? DateTime.now();
    }
    return DateTime.now();
  }

  factory MeetingModel.fromMap(Map<String, dynamic> map) {
    MeetingStatus parsedStatus;
    switch (map['status']) {
      case 'scheduled':
        parsedStatus = MeetingStatus.scheduled;
        break;
      case 'draft':
        parsedStatus = MeetingStatus.draft;
        break;
      case 'pending_vice_dean':
        parsedStatus = MeetingStatus.pendingViceDean;
        break;
      case 'pending_dean':
        parsedStatus = MeetingStatus.pendingDean;
        break;
      case 'forwarded_to_presidency':
        parsedStatus = MeetingStatus.forwardedToPresidency;
        break;
      case 'rejected':
        parsedStatus = MeetingStatus.rejected;
        break;
      case 'canceled':
        parsedStatus = MeetingStatus.canceled;
        break;
      default:
        parsedStatus = MeetingStatus.scheduled;
    }

    return MeetingModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      room: map['room'] ?? '',
      agenda: List<String>.from(map['agenda'] ?? []),
      attendees: List<String>.from(map['attendees'] ?? []),
      attendeeIds: List<String>.from(map['attendeeIds'] ?? []),
      minutes: map['minutes'] ?? '',
      documentUrl: map['documentUrl'],
      status: parsedStatus,
      departmentId: map['departmentId'] ?? '',
      college: map['college'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      rejectReason: map['rejectReason'],
      previousMinutesUrl: map['previousMinutesUrl'],
      previousMinutesName: map['previousMinutesName'],
    );
  }

  MeetingModel copyWith({
    String? id,
    String? title,
    String? date,
    String? time,
    String? room,
    List<String>? agenda,
    List<String>? attendees,
    List<String>? attendeeIds,
    String? minutes,
    String? documentUrl,
    MeetingStatus? status,
    String? departmentId,
    String? college,
    DateTime? createdAt,
    String? rejectReason,
    String? previousMinutesUrl,
    String? previousMinutesName,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      room: room ?? this.room,
      agenda: agenda ?? this.agenda,
      attendees: attendees ?? this.attendees,
      attendeeIds: attendeeIds ?? this.attendeeIds,
      minutes: minutes ?? this.minutes,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
      departmentId: departmentId ?? this.departmentId,
      college: college ?? this.college,
      createdAt: createdAt ?? this.createdAt,
      rejectReason: rejectReason ?? this.rejectReason,
      previousMinutesUrl: previousMinutesUrl ?? this.previousMinutesUrl,
      previousMinutesName: previousMinutesName ?? this.previousMinutesName,
    );
  }
}
