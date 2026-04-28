import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyMemberModel {
  final String id;
  final String? userId; // حقل الربط
  final String name;
  final String email;
  final String status;

  // 📁 حقول الملفات
  final String? fileUrl;
  final String? localFilePath;

  // 👤 البيانات الشخصية والأساسية
  final String? idCardNumber;
  final String? jobNumber;
  final String? birthPlace;
  final String? birthDate;
  final String? firstAppointmentDate;
  final String? univAppointmentDate;

  // 🎓 بيانات البكالوريوس
  final String? bscDegree;
  final String? bscDate;
  final String? bscUniversity;
  final String? bscCountry;
  final String? bscAcademicTitle;
  final String? bscTitleTransferDate;
  final String? bscSpecialization;

  // 🎓 بيانات الماجستير
  final String? mscDegree;
  final String? mscDate;
  final String? mscUniversity;
  final String? mscCountry;
  final String? mscAcademicTitle;
  final String? mscTitleTransferDate;
  final String? mscDecisionNumber;
  final String? mscExactSpecialization;

  // 🎓 البيانات الحالية (الدكتوراه)
  final String? currentDegree;
  final String? currentDegreeDate;
  final String? currentUniversity;
  final String? currentCountry;

  // 📈 الترقيات
  final String? assistantProfDate;
  final String? assistantProfDecision;
  final String? assocProfDate;
  final String? assocProfDecision;

  // 🏫 الوضع الأكاديمي الحالي
  final String academicDegree; // mapped to current_academic_title
  final String? titleTransferDate;
  final String department; // mapped to department
  final String? generalSpecialization;
  final String? exactSpecialization;

  // ✈️ الإجازات (JSON)
  final String? sabbaticalLeaves;
  final String? unpaidLeaves;

  final String createdAt;

  FacultyMemberModel({
    required this.id,
    this.userId,
    required this.name,
    required this.email,
    required this.status,
    this.fileUrl,
    this.localFilePath,
    this.idCardNumber,
    this.jobNumber,
    this.birthPlace,
    this.birthDate,
    this.firstAppointmentDate,
    this.univAppointmentDate,
    this.bscDegree,
    this.bscDate,
    this.bscUniversity,
    this.bscCountry,
    this.bscAcademicTitle,
    this.bscTitleTransferDate,
    this.bscSpecialization,
    this.mscDegree,
    this.mscDate,
    this.mscUniversity,
    this.mscCountry,
    this.mscAcademicTitle,
    this.mscTitleTransferDate,
    this.mscDecisionNumber,
    this.mscExactSpecialization,
    this.currentDegree,
    this.currentDegreeDate,
    this.currentUniversity,
    this.currentCountry,
    this.assistantProfDate,
    this.assistantProfDecision,
    this.assocProfDate,
    this.assocProfDecision,
    required this.academicDegree,
    this.titleTransferDate,
    required this.department,
    this.generalSpecialization,
    this.exactSpecialization,
    this.sabbaticalLeaves,
    this.unpaidLeaves,
    required this.createdAt,
  });

  // دالة تحويل من Map (SQLite) إلى Object
  factory FacultyMemberModel.fromMap(Map<String, dynamic> map) {
    return FacultyMemberModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      name: map['name']?.toString() ?? 'غير معروف',
      email: map['email']?.toString() ?? '',
      status: map['status']?.toString() ?? 'نشط',
      fileUrl: map['file_url']?.toString(),
      localFilePath: map['local_file_path']?.toString(),
      idCardNumber: map['id_card_number']?.toString(),
      jobNumber: map['job_number']?.toString(),
      birthPlace: map['birth_place']?.toString(),
      birthDate: map['birth_date']?.toString(),
      firstAppointmentDate: map['first_appointment_date']?.toString(),
      univAppointmentDate: map['university_appointment_date']?.toString(),
      bscDegree: map['bsc_degree']?.toString(),
      bscDate: map['bsc_date']?.toString(),
      bscUniversity: map['bsc_university']?.toString(),
      bscCountry: map['bsc_country']?.toString(),
      bscAcademicTitle: map['bsc_academic_title']?.toString(),
      bscTitleTransferDate: map['bsc_title_transfer_date']?.toString(),
      bscSpecialization: map['bsc_specialization']?.toString(),
      mscDegree: map['msc_degree']?.toString(),
      mscDate: map['msc_date']?.toString(),
      mscUniversity: map['msc_university']?.toString(),
      mscCountry: map['msc_country']?.toString(),
      mscAcademicTitle: map['msc_academic_title']?.toString(),
      mscTitleTransferDate: map['msc_title_transfer_date']?.toString(),
      mscDecisionNumber: map['msc_decision_number']?.toString(),
      mscExactSpecialization: map['msc_exact_specialization']?.toString(),
      currentDegree: map['current_degree']?.toString(),
      currentDegreeDate: map['current_degree_date']?.toString(),
      currentUniversity: map['current_university']?.toString(),
      currentCountry: map['current_country']?.toString(),
      assistantProfDate: map['assistant_prof_date']?.toString(),
      assistantProfDecision: map['assistant_prof_decision']?.toString(),
      assocProfDate: map['assoc_prof_date']?.toString(),
      assocProfDecision: map['assoc_prof_decision']?.toString(),
      academicDegree: map['current_academic_title']?.toString() ?? 'غير محدد',
      titleTransferDate: map['title_transfer_date']?.toString(),
      department: map['department']?.toString() ?? 'غير محدد',
      generalSpecialization: map['general_specialization']?.toString(),
      exactSpecialization: map['exact_specialization']?.toString(),
      sabbaticalLeaves: map['sabbatical_leaves']?.toString(),
      unpaidLeaves: map['unpaid_leaves']?.toString(),
      createdAt: map['created_at']?.toString() ?? '',
    );
  }

  // ====================================================================
  // الدالة المفقودة: تحويل البيانات القادمة من Firebase Firestore إلى Object
  // ====================================================================
  factory FacultyMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return FacultyMemberModel(
      id: doc.id,
      userId: data['user_id']?.toString(),
      name: data['name']?.toString() ?? 'غير معروف',
      email: data['email']?.toString() ?? '',
      status: data['status']?.toString() ?? 'نشط',
      fileUrl: data['file_url']?.toString(),
      localFilePath: data['local_file_path']?.toString(),
      idCardNumber: data['id_card_number']?.toString(),
      jobNumber: data['job_number']?.toString(),
      birthPlace: data['birth_place']?.toString(),
      birthDate: data['birth_date']?.toString(),
      firstAppointmentDate: data['first_appointment_date']?.toString(),
      univAppointmentDate: data['university_appointment_date']?.toString(),
      bscDegree: data['bsc_degree']?.toString(),
      bscDate: data['bsc_date']?.toString(),
      bscUniversity: data['bsc_university']?.toString(),
      bscCountry: data['bsc_country']?.toString(),
      bscAcademicTitle: data['bsc_academic_title']?.toString(),
      bscTitleTransferDate: data['bsc_title_transfer_date']?.toString(),
      bscSpecialization: data['bsc_specialization']?.toString(),
      mscDegree: data['msc_degree']?.toString(),
      mscDate: data['msc_date']?.toString(),
      mscUniversity: data['msc_university']?.toString(),
      mscCountry: data['msc_country']?.toString(),
      mscAcademicTitle: data['msc_academic_title']?.toString(),
      mscTitleTransferDate: data['msc_title_transfer_date']?.toString(),
      mscDecisionNumber: data['msc_decision_number']?.toString(),
      mscExactSpecialization: data['msc_exact_specialization']?.toString(),
      currentDegree: data['current_degree']?.toString(),
      currentDegreeDate: data['current_degree_date']?.toString(),
      currentUniversity: data['current_university']?.toString(),
      currentCountry: data['current_country']?.toString(),
      assistantProfDate: data['assistant_prof_date']?.toString(),
      assistantProfDecision: data['assistant_prof_decision']?.toString(),
      assocProfDate: data['assoc_prof_date']?.toString(),
      assocProfDecision: data['assoc_prof_decision']?.toString(),
      academicDegree: data['current_academic_title']?.toString() ?? 'غير محدد',
      titleTransferDate: data['title_transfer_date']?.toString(),
      department: data['department']?.toString() ?? 'غير محدد',
      generalSpecialization: data['general_specialization']?.toString(),
      exactSpecialization: data['exact_specialization']?.toString(),
      sabbaticalLeaves: data['sabbatical_leaves']?.toString(),
      unpaidLeaves: data['unpaid_leaves']?.toString(),
      createdAt: _parseDate(data['created_at'] ?? data['createdAt']),
    );
  }

  // ====================================================================
  // دالة مساعدة لمعالجة التاريخ بأمان (سواء كان Timestamp أو String)
  // ====================================================================
  static String _parseDate(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    if (value is String) {
      return value.split(' ')[0];
    }
    return '-';
  }

  // دالة تحويل Object إلى Map (تُستخدم للحفظ في SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'status': status,
      'file_url': fileUrl,
      'local_file_path': localFilePath,
      'id_card_number': idCardNumber,
      'job_number': jobNumber,
      'birth_place': birthPlace,
      'birth_date': birthDate,
      'first_appointment_date': firstAppointmentDate,
      'university_appointment_date': univAppointmentDate,
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
      'current_academic_title': academicDegree,
      'title_transfer_date': titleTransferDate,
      'department': department,
      'general_specialization': generalSpecialization,
      'exact_specialization': exactSpecialization,
      'sabbatical_leaves': sabbaticalLeaves,
      'unpaid_leaves': unpaidLeaves,
      'created_at': createdAt,
    };
  }
}
