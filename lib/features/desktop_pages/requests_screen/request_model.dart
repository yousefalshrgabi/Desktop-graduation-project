import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class RequestModel {
  final String id;
  final String title;
  final String applicantName;
  final String senderCollege; // الكلية أو الجهة المرسلة
  final String destinationCollege; // الكلية الموجه إليها الطلب
  final String type; // نوع الطلب
  final String description; // تفاصيل أو ملاحظات حول الطلب
  final DateTime dateSent;
  final DateTime? dateReplied;
  final String status; // قيد الانتظار، مقبول، مرفوض
  final String? rejectionReason;
  final String? fileUrl;
  final String? localFilePath;
  final String? senderId;
  final Map<String, dynamic>? extraData; // 👈 لتخزين البيانات التقنية المطلوب تعديلها

  RequestModel({
    required this.id,
    required this.title,
    required this.applicantName,
    required this.senderCollege,
    required this.destinationCollege,
    required this.type,
    required this.description,
    required this.dateSent,
    this.dateReplied,
    required this.status,
    this.rejectionReason,
    this.fileUrl,
    this.localFilePath,
    this.senderId,
    this.extraData,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RequestModel(
      id: documentId,
      title: map['title'] ?? '',
      applicantName: map['applicantName'] ?? '',
      senderCollege: map['senderCollege'] ?? '',
      destinationCollege: map['destinationCollege'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      dateSent: map['dateSent'] != null
          ? (map['dateSent'] is Timestamp 
              ? (map['dateSent'] as Timestamp).toDate() 
              : DateTime.tryParse(map['dateSent'].toString()) ?? DateTime.now())
          : DateTime.now(),
      dateReplied: map['dateReplied'] != null
          ? (map['dateReplied'] is Timestamp
              ? (map['dateReplied'] as Timestamp).toDate()
              : DateTime.tryParse(map['dateReplied'].toString()))
          : null,
      status: map['status'] ?? 'قيد الانتظار',
      rejectionReason: map['rejectionReason'],
      fileUrl: map['fileUrl'],
      localFilePath: map['localFilePath'],
      senderId: map['senderId'],
      extraData: map['extraData'] != null
          ? (map['extraData'] is String
              ? jsonDecode(map['extraData'])
              : Map<String, dynamic>.from(map['extraData']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'applicantName': applicantName,
      'senderCollege': senderCollege,
      'destinationCollege': destinationCollege,
      'type': type,
      'description': description,
      'dateSent': FieldValue.serverTimestamp(),
      'dateReplied':
          dateReplied != null ? Timestamp.fromDate(dateReplied!) : null,
      'status': status,
      'rejectionReason': rejectionReason,
      'fileUrl': fileUrl,
      'localFilePath': localFilePath,
      'senderId': senderId,
      'extraData': extraData,
    };
  }
}
