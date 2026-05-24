import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String status;
  final String createdAt;

  // 🌟 حقول الملفات المرفقة (تمت إضافتها)
  final String localFilePath;
  final String fileUrl;

  final String fileNumber;
  final String idCardNumber;
  final String jobNumber;
  final String birthPlace;
  final String birthDate;

  final String firstAppointmentDate;
  final String universityAppointmentDate;

  final String bscDegree;
  final String bscDate;
  final String bscUniversity;
  final String bscCountry;
  final String bscAcademicTitle;
  final String bscTitleTransferDate;
  final String bscSpecialization;

  final String mscDegree;
  final String mscDate;
  final String mscUniversity;
  final String mscCountry;
  final String mscAcademicTitle;
  final String mscTitleTransferDate;
  final String mscDecisionNumber;
  final String mscExactSpecialization;

  final String currentDegree;
  final String currentDegreeDate;
  final String currentUniversity;
  final String currentCountry;

  final String assistantProfDate;
  final String assistantProfDecision;

  final String assocProfDate;
  final String assocProfDecision;

  final String currentAcademicTitle;
  final String titleTransferDate;
  final String department;

  final String generalSpecialization;
  final String exactSpecialization;

  final String sabbaticalLeaves;
  final String unpaidLeaves;

  FacultyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.localFilePath = '', // 👈 تمت الإضافة
    this.fileUrl = '', // 👈 تمت الإضافة
    this.fileNumber = '',
    this.idCardNumber = '',
    this.jobNumber = '',
    this.birthPlace = '',
    this.birthDate = '',
    this.firstAppointmentDate = '',
    this.universityAppointmentDate = '',
    this.bscDegree = '',
    this.bscDate = '',
    this.bscUniversity = '',
    this.bscCountry = '',
    this.bscAcademicTitle = '',
    this.bscTitleTransferDate = '',
    this.bscSpecialization = '',
    this.mscDegree = '',
    this.mscDate = '',
    this.mscUniversity = '',
    this.mscCountry = '',
    this.mscAcademicTitle = '',
    this.mscTitleTransferDate = '',
    this.mscDecisionNumber = '',
    this.mscExactSpecialization = '',
    this.currentDegree = '',
    this.currentDegreeDate = '',
    this.currentUniversity = '',
    this.currentCountry = '',
    this.assistantProfDate = '',
    this.assistantProfDecision = '',
    this.assocProfDate = '',
    this.assocProfDecision = '',
    this.currentAcademicTitle = '',
    this.titleTransferDate = '',
    this.department = '',
    this.generalSpecialization = '',
    this.exactSpecialization = '',
    this.sabbaticalLeaves = '',
    this.unpaidLeaves = '',
  });

  // 🌟 دالة لنسخ الكائن مع تعديل بعض الحقول (للملفات)
  FacultyMemberModel copyWith({
    String? localFilePath,
    String? fileUrl,
  }) {
    return FacultyMemberModel(
      id: id,
      userId: userId,
      name: name,
      status: status,
      createdAt: createdAt,
      localFilePath: localFilePath ?? this.localFilePath, // 👈
      fileUrl: fileUrl ?? this.fileUrl, // 👈
      fileNumber: fileNumber,
      idCardNumber: idCardNumber,
      jobNumber: jobNumber,
      birthPlace: birthPlace,
      birthDate: birthDate,
      firstAppointmentDate: firstAppointmentDate,
      universityAppointmentDate: universityAppointmentDate,
      bscDegree: bscDegree,
      bscDate: bscDate,
      bscUniversity: bscUniversity,
      bscCountry: bscCountry,
      bscAcademicTitle: bscAcademicTitle,
      bscTitleTransferDate: bscTitleTransferDate,
      bscSpecialization: bscSpecialization,
      mscDegree: mscDegree,
      mscDate: mscDate,
      mscUniversity: mscUniversity,
      mscCountry: mscCountry,
      mscAcademicTitle: mscAcademicTitle,
      mscTitleTransferDate: mscTitleTransferDate,
      mscDecisionNumber: mscDecisionNumber,
      mscExactSpecialization: mscExactSpecialization,
      currentDegree: currentDegree,
      currentDegreeDate: currentDegreeDate,
      currentUniversity: currentUniversity,
      currentCountry: currentCountry,
      assistantProfDate: assistantProfDate,
      assistantProfDecision: assistantProfDecision,
      assocProfDate: assocProfDate,
      assocProfDecision: assocProfDecision,
      currentAcademicTitle: currentAcademicTitle,
      titleTransferDate: titleTransferDate,
      department: department,
      generalSpecialization: generalSpecialization,
      exactSpecialization: exactSpecialization,
      sabbaticalLeaves: sabbaticalLeaves,
      unpaidLeaves: unpaidLeaves,
    );
  }

  factory FacultyMemberModel.fromMap(Map<String, dynamic> map) {
    return FacultyMemberModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'نشط',
      createdAt: map['created_at']?.toString() ?? '',
      localFilePath: map['local_file_path']?.toString() ?? '', // 👈
      fileUrl: map['file_url']?.toString() ?? '', // 👈
      fileNumber: map['file_number']?.toString() ?? '',
      idCardNumber: map['id_card_number']?.toString() ?? '',
      jobNumber: map['job_number']?.toString() ?? '',
      birthPlace: map['birth_place']?.toString() ?? '',
      birthDate: map['birth_date']?.toString() ?? '',
      firstAppointmentDate: map['first_appointment_date']?.toString() ?? '',
      universityAppointmentDate:
          map['university_appointment_date']?.toString() ?? '',
      bscDegree: map['bsc_degree']?.toString() ?? '',
      bscDate: map['bsc_date']?.toString() ?? '',
      bscUniversity: map['bsc_university']?.toString() ?? '',
      bscCountry: map['bsc_country']?.toString() ?? '',
      bscAcademicTitle: map['bsc_academic_title']?.toString() ?? '',
      bscTitleTransferDate: map['bsc_title_transfer_date']?.toString() ?? '',
      bscSpecialization: map['bsc_specialization']?.toString() ?? '',
      mscDegree: map['msc_degree']?.toString() ?? '',
      mscDate: map['msc_date']?.toString() ?? '',
      mscUniversity: map['msc_university']?.toString() ?? '',
      mscCountry: map['msc_country']?.toString() ?? '',
      mscAcademicTitle: map['msc_academic_title']?.toString() ?? '',
      mscTitleTransferDate: map['msc_title_transfer_date']?.toString() ?? '',
      mscDecisionNumber: map['msc_decision_number']?.toString() ?? '',
      mscExactSpecialization: map['msc_exact_specialization']?.toString() ?? '',
      currentDegree: map['current_degree']?.toString() ?? '',
      currentDegreeDate: map['current_degree_date']?.toString() ?? '',
      currentUniversity: map['current_university']?.toString() ?? '',
      currentCountry: map['current_country']?.toString() ?? '',
      assistantProfDate: map['assistant_prof_date']?.toString() ?? '',
      assistantProfDecision: map['assistant_prof_decision']?.toString() ?? '',
      assocProfDate: map['assoc_prof_date']?.toString() ?? '',
      assocProfDecision: map['assoc_prof_decision']?.toString() ?? '',
      currentAcademicTitle: map['current_academic_title']?.toString() ?? '',
      titleTransferDate: map['title_transfer_date']?.toString() ?? '',
      department: map['department']?.toString() ?? '',
      generalSpecialization: map['general_specialization']?.toString() ?? '',
      exactSpecialization: map['exact_specialization']?.toString() ?? '',
      sabbaticalLeaves: map['sabbatical_leaves']?.toString() ?? '',
      unpaidLeaves: map['unpaid_leaves']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId.isEmpty ? null : userId,
      'name': name,
      'status': status,
      'created_at': createdAt,
      'local_file_path': localFilePath, // 👈 يتم تجهيزها للرفع للفايربيس
      'file_url': fileUrl, // 👈 يتم تجهيزها للرفع للفايربيس
      'file_number': fileNumber,
      'id_card_number': idCardNumber,
      'job_number': jobNumber,
      'birth_place': birthPlace,
      'birth_date': birthDate,
      'first_appointment_date': firstAppointmentDate,
      'university_appointment_date': universityAppointmentDate,
      'bsc_degree': bscDegree,
      'bsc_date': bscDate,
      'bsc_university': bscUniversity,
      'bsc_country': bscCountry,
      'bsc_academic_title': bscAcademicTitle,
      'bsc_title_transfer_date': bscTitleTransferDate,
      'bsc_specialization': bscSpecialization,
      'msc_degree': mscDegree,
      'msc_date': mscDate,
      'msc_university': mscUniversity,
      'msc_country': mscCountry,
      'msc_academic_title': mscAcademicTitle,
      'msc_title_transfer_date': mscTitleTransferDate,
      'msc_decision_number': mscDecisionNumber,
      'msc_exact_specialization': mscExactSpecialization,
      'current_degree': currentDegree,
      'current_degree_date': currentDegreeDate,
      'current_university': currentUniversity,
      'current_country': currentCountry,
      'assistant_prof_date': assistantProfDate,
      'assistant_prof_decision': assistantProfDecision,
      'assoc_prof_date': assocProfDate,
      'assoc_prof_decision': assocProfDecision,
      'current_academic_title': currentAcademicTitle,
      'title_transfer_date': titleTransferDate,
      'department': department,
      'general_specialization': generalSpecialization,
      'exact_specialization': exactSpecialization,
      'sabbatical_leaves': sabbaticalLeaves,
      'unpaid_leaves': unpaidLeaves,
    };
  }

  factory FacultyMemberModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // التحقق من نوع التاريخ إذا كان قادماً كـ Timestamp من الفايربيس
    String parseDate(dynamic dateField) {
      if (dateField is Timestamp) return dateField.toDate().toIso8601String();
      return dateField?.toString() ?? DateTime.now().toIso8601String();
    }

    return FacultyMemberModel(
      id: doc.id,
      userId: data['user_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      status: data['status']?.toString() ?? 'نشط',
      createdAt: parseDate(data['created_at']),
      localFilePath: data['local_file_path']?.toString() ?? '', // 👈
      fileUrl: data['file_url']?.toString() ?? '', // 👈
      fileNumber: data['file_number']?.toString() ?? '',
      idCardNumber: data['id_card_number']?.toString() ?? '',
      jobNumber: data['job_number']?.toString() ?? '',
      birthPlace: data['birth_place']?.toString() ?? '',
      birthDate: data['birth_date']?.toString() ?? '',
      firstAppointmentDate: data['first_appointment_date']?.toString() ?? '',
      universityAppointmentDate:
          data['university_appointment_date']?.toString() ?? '',
      bscDegree: data['bsc_degree']?.toString() ?? '',
      bscDate: data['bsc_date']?.toString() ?? '',
      bscUniversity: data['bsc_university']?.toString() ?? '',
      bscCountry: data['bsc_country']?.toString() ?? '',
      bscAcademicTitle: data['bsc_academic_title']?.toString() ?? '',
      bscTitleTransferDate: data['bsc_title_transfer_date']?.toString() ?? '',
      bscSpecialization: data['bsc_specialization']?.toString() ?? '',
      mscDegree: data['msc_degree']?.toString() ?? '',
      mscDate: data['msc_date']?.toString() ?? '',
      mscUniversity: data['msc_university']?.toString() ?? '',
      mscCountry: data['msc_country']?.toString() ?? '',
      mscAcademicTitle: data['msc_academic_title']?.toString() ?? '',
      mscTitleTransferDate: data['msc_title_transfer_date']?.toString() ?? '',
      mscDecisionNumber: data['msc_decision_number']?.toString() ?? '',
      mscExactSpecialization:
          data['msc_exact_specialization']?.toString() ?? '',
      currentDegree: data['current_degree']?.toString() ?? '',
      currentDegreeDate: data['current_degree_date']?.toString() ?? '',
      currentUniversity: data['current_university']?.toString() ?? '',
      currentCountry: data['current_country']?.toString() ?? '',
      assistantProfDate: data['assistant_prof_date']?.toString() ?? '',
      assistantProfDecision: data['assistant_prof_decision']?.toString() ?? '',
      assocProfDate: data['assoc_prof_date']?.toString() ?? '',
      assocProfDecision: data['assoc_prof_decision']?.toString() ?? '',
      currentAcademicTitle: data['current_academic_title']?.toString() ?? '',
      titleTransferDate: data['title_transfer_date']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      generalSpecialization: data['general_specialization']?.toString() ?? '',
      exactSpecialization: data['exact_specialization']?.toString() ?? '',
      sabbaticalLeaves: data['sabbatical_leaves']?.toString() ?? '',
      unpaidLeaves: data['unpaid_leaves']?.toString() ?? '',
    );
  }
}
