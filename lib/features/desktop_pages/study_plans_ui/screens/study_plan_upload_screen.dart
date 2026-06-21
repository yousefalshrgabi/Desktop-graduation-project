import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/study_plan.dart';
import '../services/study_plan_firestore_service.dart';
import '../services/study_plan_parser.dart';
import '../utils/level_labels.dart';
import '../utils/study_plan_file_hints.dart';
import '../widgets/study_plan_course_table.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

/// Upload a study-plan Excel file for any college/program to Local Database.
class StudyPlanUploadScreen extends StatefulWidget {
  const StudyPlanUploadScreen({
    super.key,
    this.initialCollege = 'كلية الحاسبات',
    this.canEdit = false,
    this.lockCollege = false,
  });

  final String initialCollege;
  final bool canEdit;
  final bool lockCollege;

  @override
  State<StudyPlanUploadScreen> createState() => _StudyPlanUploadScreenState();
}

class _StudyPlanUploadScreenState extends State<StudyPlanUploadScreen> {
  final _parser = StudyPlanParser();
  final _service = StudyPlanFirestoreService();
  final _collegeController = TextEditingController();
  final _programController = TextEditingController();
  final _trackController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage =
      'اختر ملف Excel لخطة دراسية (.xlsx) ثم حدد الكلية والبرنامج';
  StudyPlan? _preview;
  List<String> _colleges = [];
  int? _trackStartSemester;

  @override
  void initState() {
    super.initState();
    _collegeController.text = widget.lockCollege ? widget.initialCollege : '';
    _loadColleges();
  }

  @override
  void dispose() {
    _collegeController.dispose();
    _programController.dispose();
    _trackController.dispose();
    super.dispose();
  }

  Future<void> _loadColleges() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('colleges');
      final names = result
          .map((c) => (c['ar_name'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
      names.sort();
      if (mounted) setState(() => _colleges = names);
    } catch (_) {}
  }

  Future<void> _pickAndParse() async {
    final previousPreview = _preview;
    final enteredTrack = _trackController.text.trim();
    final previousTrack = (previousPreview?.trackName ?? '').trim();
    final trackWasInheritedFromPreviousFile =
        previousPreview != null && enteredTrack == previousTrack;

    setState(() {
      _isLoading = true;
      _preview = null;
      _statusMessage = 'جاري اختيار الملف...';
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم الإلغاء.';
        });
        return;
      }

      final file = result.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('تعذر قراءة الملف');
      _trackStartSemester = null;

      final programHint = _programController.text.trim().isNotEmpty
          ? _programController.text.trim()
          : StudyPlanFileHints.programFromFileName(file.name);
      final manuallyEnteredTrack =
          enteredTrack.isNotEmpty && !trackWasInheritedFromPreviousFile
              ? enteredTrack
              : null;
      final trackHint = manuallyEnteredTrack ??
          StudyPlanFileHints.trackFromFileName(file.name);

      if (programHint != null && _programController.text.trim().isEmpty) {
        _programController.text = programHint;
      }
      if (trackWasInheritedFromPreviousFile) {
        _trackController.clear();
      }
      if (trackHint != null && _trackController.text.trim().isEmpty) {
        _trackController.text = trackHint;
      }

      setState(() => _statusMessage = 'جاري تحليل الخطة...');

      final plan = _parser.parseBytes(
        bytes,
        collegeName: _collegeController.text.trim(),
        defaultProgramName: _programController.text.trim().isEmpty
            ? programHint
            : _programController.text.trim(),
        defaultTrackName: _trackController.text.trim().isEmpty
            ? trackHint
            : _trackController.text.trim(),
        sourceFileName: file.name,
      );

      if (plan.semesters.isEmpty) {
        throw Exception(
          'لم يُستخرج أي مقرر. تأكد أن الملف يطابق نموذج «خطة برنامج» الرسمي.',
        );
      }

      setState(() {
        if ((plan.trackName ?? '').trim().isNotEmpty &&
            _trackController.text.trim().isEmpty) {
          _trackController.text = plan.trackName!.trim();
        }
        _preview = plan;
        _isLoading = false;
        _statusMessage =
            'معاينة: ${plan.displayTitle} — ${plan.semesters.length} فصل/قسم، ${plan.totalCourses} مقرر، ${plan.totalCreditHours} ساعة معتمدة';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'خطأ: $e';
      });
    }
  }

  Future<void> _uploadPreview() async {
    final previewPlan = _preview;
    if (previewPlan == null) return;
    final plan = _planWithCurrentFields(previewPlan);
    if (plan.collegeName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار أو إدخال اسم الكلية أولاً.'),
        ),
      );
      return;
    }

    if ((plan.trackName ?? '').trim().isNotEmpty &&
        plan.trackStartSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد المستوى الذي يبدأ منه اختلاف المسارات'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري حفظ الخطة محلياً...';
    });

    try {
      if (!await _confirmTrackReplacements([plan])) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم إلغاء الحفظ دون استبدال المسار الموجود.';
        });
        return;
      }
      await _service.savePlan(plan);
      if (!mounted) return;
      setState(() {
        _preview = plan;
        _isLoading = false;
        _statusMessage = 'تم حفظ خطة المسار كاملة بنجاح (${plan.documentId})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الخطة كاملة، مع تخزين المقررات المشتركة مرة واحدة',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'فشل الحفظ: $e';
      });
    }
  }

  Future<bool> _confirmTrackReplacements(List<StudyPlan> plans) async {
    final existingTracks = <StudyPlanSummary>[];
    for (final plan in plans) {
      if ((plan.trackName ?? '').trim().isEmpty) continue;
      final existing = await _service.getPlanSummary(plan.documentId);
      if (existing != null) existingTracks.add(existing);
    }
    if (!mounted) return false;
    if (existingTracks.isEmpty) return true;

    final names =
        existingTracks.map((plan) => '• ${plan.displayTitle}').join('\n');
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('المسار موجود مسبقًا'),
            content: Text(
              'سيؤدي الحفظ إلى استبدال بيانات المسار التالي:\n\n$names\n\n'
              'تأكد أن اسم المسار صحيح قبل المتابعة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('استبدال المسار'),
              ),
            ],
          ),
        ) ??
        false;
  }

  StudyPlan _planWithCurrentFields(StudyPlan plan) {
    final college = _collegeController.text.trim();
    final program = _programController.text.trim();
    final track = _trackController.text.trim();

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

  Future<void> _importBundledCsPlans() async {
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

    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري استيراد خطط كلية الحاسبات من الأصول...';
    });

    var ok = 0;
    try {
      for (final item in bundles) {
        final data = await rootBundle.load(item.asset);
        final plan = _parser.parseBytes(
          data.buffer.asUint8List(),
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'تم استيراد $ok خطط إلى التطبيق بنجاح';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استيراد $ok خطط دراسية')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'فشل الاستيراد: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: const SharedDesktopAppBar(customTitle: 'رفع خطة دراسية'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بيانات الربط',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (widget.lockCollege)
                      TextField(
                        controller: _collegeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'الكلية',
                          border: OutlineInputBorder(),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'الكلية',
                          border: OutlineInputBorder(),
                        ),
                        value: _colleges.contains(_collegeController.text)
                            ? _collegeController.text
                            : null,
                        hint: const Text('اختر الكلية من القائمة...'),
                        items: _colleges.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _collegeController.text = val;
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _programController,
                      decoration: const InputDecoration(
                        labelText:
                            'اسم البرنامج (يُستنتج من الملف إن تُرك فارغاً)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trackController,
                      decoration: const InputDecoration(
                        labelText:
                            'المسار (اختياري — مثل: الشبكات، تطوير البرمجيات)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_trackController.text.trim().isNotEmpty ||
                        (_preview?.trackName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _trackStartSemester,
                        decoration: const InputDecoration(
                          labelText: 'الفصل الذي يبدأ منه اختلاف المسارات',
                          helperText:
                              'الفصول السابقة تُجمع للبرنامج، ومن هذا الفصل تُفصل حسب المسار',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(8, (index) => index + 1)
                            .map(
                              (semester) => DropdownMenuItem<int>(
                                value: semester,
                                child: Text(
                                  LevelLabels.semesterLabel(semester),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _trackStartSemester = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'كل ملف مسار يُحفظ ويُعرض كخطة كاملة. مستوى بداية الاختلاف يحدد متى تُفصل المسارات في الجداول.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading || !widget.canEdit ? null : _pickAndParse,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('اختيار ملف Excel وتحليله'),
            ),
            const SizedBox(height: 8),
            // OutlinedButton.icon(
            //   onPressed:
            //       _isLoading || !widget.canEdit ? null : _importBundledCsPlans,
            //   icon: const Icon(Icons.cloud_download_rounded),
            //   label: const Text('استيراد خطط كلية الحاسبات (من assets)'),
            // ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed:
                    _isLoading || !widget.canEdit ? null : _uploadPreview,
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ الخطة'),
              ),
              const SizedBox(height: 12),
              ...preview.semesters.map(
                (s) => Card(
                  child: ExpansionTile(
                    title: Text(s.labelAr),
                    subtitle: Text('${s.courses.length} مقرر'),
                    children: [
                      StudyPlanCourseTable(courses: s.courses, compact: true),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_statusMessage, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
