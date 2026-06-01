import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingStatus {
  scheduled,
  draft,
  pendingViceDean,
  pendingDean,
  forwardedToPresidency,
  rejected,
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
    }
  }
}

class MeetingModel {
  final String id;
  final String title;
  final String date;
  final String time;
  final List<String> agenda;
  final List<String> attendees;
  final String minutes;
  final String? documentUrl;
  final MeetingStatus status;
  final String departmentId;
  final String college;
  final DateTime createdAt;
  final String? rejectReason;

  MeetingModel({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.agenda,
    required this.attendees,
    required this.minutes,
    this.documentUrl,
    required this.status,
    required this.departmentId,
    required this.college,
    required this.createdAt,
    this.rejectReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'agenda': agenda,
      'attendees': attendees,
      'minutes': minutes,
      'documentUrl': documentUrl,
      'status': status.key,
      'departmentId': departmentId,
      'college': college,
      'createdAt': createdAt.toIso8601String(),
      'rejectReason': rejectReason,
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
      default:
        parsedStatus = MeetingStatus.scheduled;
    }

    return MeetingModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      agenda: List<String>.from(map['agenda'] ?? []),
      attendees: List<String>.from(map['attendees'] ?? []),
      minutes: map['minutes'] ?? '',
      documentUrl: map['documentUrl'],
      status: parsedStatus,
      departmentId: map['departmentId'] ?? '',
      college: map['college'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      rejectReason: map['rejectReason'],
    );
  }

  MeetingModel copyWith({
    String? id,
    String? title,
    String? date,
    String? time,
    List<String>? agenda,
    List<String>? attendees,
    String? minutes,
    String? documentUrl,
    MeetingStatus? status,
    String? departmentId,
    String? college,
    DateTime? createdAt,
    String? rejectReason,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      agenda: agenda ?? this.agenda,
      attendees: attendees ?? this.attendees,
      minutes: minutes ?? this.minutes,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
      departmentId: departmentId ?? this.departmentId,
      college: college ?? this.college,
      createdAt: createdAt ?? this.createdAt,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }
}
