import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import '../models/study_plan.dart';
import '../services/study_plan_firestore_service.dart';
import '../services/study_plan_parser.dart';
import '../utils/study_plan_file_hints.dart';

class StudyPlanUploadViewModel extends ChangeNotifier {
  final _parser = StudyPlanParser();
  final _service = StudyPlanFirestoreService();
  
  final collegeController = TextEditingController();
  final programController = TextEditingController();
  final trackController = TextEditingController();

  final String initialCollege;
  final bool canEdit;
  final bool lockCollege;

  StudyPlanUploadViewModel({
    required this.initialCollege,
    required this.canEdit,
    required this.lockCollege,
  }) {
    collegeController.text = lockCollege ? initialCollege : '';
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _statusMessage = 'اختر ملف Excel لخطة دراسية (.xlsx) ثم حدد الكلية والبرنامج';
  String get statusMessage => _statusMessage;

  StudyPlan? _preview;
  StudyPlan? get preview => _preview;

  List<String> _colleges = [];
  List<String> get colleges => _colleges;

  int? _trackStartSemester;
  int? get trackStartSemester => _trackStartSemester;

  void disposeControllers() {
    collegeController.dispose();
    programController.dispose();
    trackController.dispose();
  }

  Future<void> loadColleges() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('colleges');
      final names = result
          .map((c) => (c['ar_name'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
      names.sort();
      _colleges = names;
      notifyListeners();
    } catch (_) {}
  }

  void setTrackStartSemester(int? val) {
    _trackStartSemester = val;
    notifyListeners();
  }

  void setCollegeText(String val) {
    collegeController.text = val;
    notifyListeners();
  }

  void onTrackChanged(String val) {
    notifyListeners();
  }

  Future<void> pickAndParse() async {
    final previousPreview = _preview;
    final enteredTrack = trackController.text.trim();
    final previousTrack = (previousPreview?.trackName ?? '').trim();
    final trackWasInheritedFromPreviousFile =
        previousPreview != null && enteredTrack == previousTrack;

    _isLoading = true;
    _preview = null;
    _statusMessage = 'جاري اختيار الملف...';
    notifyListeners();

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null) {
        _isLoading = false;
        _statusMessage = 'تم الإلغاء.';
        notifyListeners();
        return;
      }

      final file = result.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('تعذر قراءة الملف');
      _trackStartSemester = null;

      final programHint = programController.text.trim().isNotEmpty
          ? programController.text.trim()
          : StudyPlanFileHints.programFromFileName(file.name);
      final manuallyEnteredTrack =
          enteredTrack.isNotEmpty && !trackWasInheritedFromPreviousFile
              ? enteredTrack
              : null;
      final trackHint = manuallyEnteredTrack ??
          StudyPlanFileHints.trackFromFileName(file.name);

      if (programHint != null && programController.text.trim().isEmpty) {
        programController.text = programHint;
      }
      if (trackWasInheritedFromPreviousFile) {
        trackController.clear();
      }
      if (trackHint != null && trackController.text.trim().isEmpty) {
        trackController.text = trackHint;
      }

      _statusMessage = 'جاري تحليل الخطة...';
      notifyListeners();

      final plan = _parser.parseBytes(
        bytes,
        collegeName: collegeController.text.trim(),
        defaultProgramName: programController.text.trim().isEmpty
            ? programHint
            : programController.text.trim(),
        defaultTrackName: trackController.text.trim().isEmpty
            ? trackHint
            : trackController.text.trim(),
        sourceFileName: file.name,
      );

      if (plan.semesters.isEmpty) {
        throw Exception(
          'لم يُستخرج أي مقرر. تأكد أن الملف يطابق نموذج «خطة برنامج» الرسمي.',
        );
      }

      if ((plan.trackName ?? '').trim().isNotEmpty &&
          trackController.text.trim().isEmpty) {
        trackController.text = plan.trackName!.trim();
      }
      _preview = plan;
      _isLoading = false;
      _statusMessage =
          'معاينة: ${plan.displayTitle} — ${plan.semesters.length} فصل/قسم، ${plan.totalCourses} مقرر، ${plan.totalCreditHours} ساعة معتمدة';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _statusMessage = 'خطأ: $e';
      notifyListeners();
    }
  }

  StudyPlan planWithCurrentFields(StudyPlan plan) {
    final college = collegeController.text.trim();
    final program = programController.text.trim();
    final track = trackController.text.trim();

    return StudyPlan(
      collegeName: college.isEmpty ? plan.collegeName : college,
      programName: program.isEmpty ? plan.programName : program,
      trackName: track.isEmpty ? plan.trackName : track,
      trackStartSemester: track.isEmpty && (plan.trackName ?? '').trim().isEmpty
          ? null
          : _trackStartSemester ?? plan.trackStartSemester,
      degreeNameAr: plan.degreeNameAr,
      degreeNameEn: plan.degreeNameEn,
      planStartYear: plan.planStartYear,
      semesters: plan.semesters,
      sourceFileName: plan.sourceFileName,
      isElectiveOnly: plan.isElectiveOnly,
    );
  }

  Future<bool> confirmTrackReplacements(StudyPlan plan) async {
    if ((plan.trackName ?? '').trim().isEmpty) return true;
    final existing = await _service.getPlanSummary(plan.documentId);
    return existing != null;
  }

  Future<void> savePlan(StudyPlan plan) async {
    _isLoading = true;
    _statusMessage = 'جاري حفظ الخطة محلياً...';
    notifyListeners();
    try {
      await _service.savePlan(plan);
      _preview = plan;
      _statusMessage = 'تم حفظ خطة المسار كاملة بنجاح (${plan.documentId})';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> importBundledCsPlans() async {
    const bundles = <({
      String asset,
      String program,
      String? track,
      int? trackStartSemester
    })>[
      (
        asset: 'assets/study_plans/cs_computer_science.xlsx',
        program: 'علوم الحاسوب',
        track: null,
        trackStartSemester: null,
      ),
      (
        asset: 'assets/study_plans/cs_information_security.xlsx',
        program: 'أمن المعلومات',
        track: null,
        trackStartSemester: null,
      ),
      (
        asset: 'assets/study_plans/cs_it_networks.xlsx',
        program: 'تقنية المعلومات',
        track: 'الشبكات',
        trackStartSemester: 5,
      ),
      (
        asset: 'assets/study_plans/cs_it_software.xlsx',
        program: 'تقنية المعلومات',
        track: 'تطوير البرمجيات',
        trackStartSemester: 5,
      ),
    ];

    _isLoading = true;
    _statusMessage = 'جاري استيراد خطط كلية الحاسبات من الأصول...';
    notifyListeners();

    var ok = 0;
    try {
      for (final item in bundles) {
        final data = await rootBundle.load(item.asset);
        final plan = _parser.parseBytes(
          data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          collegeName: 'كلية الحاسبات',
          defaultProgramName: item.program,
          defaultTrackName: item.track,
          sourceFileName: item.asset.split('/').last,
        );
        await _service.savePlan(
          StudyPlan(
            collegeName: plan.collegeName,
            programName: plan.programName,
            trackName: plan.trackName,
            trackStartSemester: item.trackStartSemester,
            degreeNameAr: plan.degreeNameAr,
            degreeNameEn: plan.degreeNameEn,
            planStartYear: plan.planStartYear,
            semesters: plan.semesters,
            sourceFileName: plan.sourceFileName,
            isElectiveOnly: plan.isElectiveOnly,
          ),
        );
        ok++;
      }
      _isLoading = false;
      _statusMessage = 'تم استيراد $ok خطط إلى التطبيق بنجاح';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _statusMessage = 'فشل الاستيراد: $e';
      notifyListeners();
      rethrow;
    }
  }
}
