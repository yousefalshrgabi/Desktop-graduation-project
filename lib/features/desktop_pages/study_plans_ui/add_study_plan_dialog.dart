import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'study_plans_model.dart';
import 'study_plans_viewmodel.dart';
import 'course_form_dialog.dart';

class AddStudyPlanDialog extends StatefulWidget {
  final StudyPlansViewModel viewModel;
  const AddStudyPlanDialog({super.key, required this.viewModel});

  @override
  State<AddStudyPlanDialog> createState() => _AddStudyPlanDialogState();
}

class _AddStudyPlanDialogState extends State<AddStudyPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  String? _selectedProgramId;
  String? _selectedTrackId;
  SemesterOption? _selectedSemester;

  final _arLevelCtrl = TextEditingController();
  final _enLevelCtrl = TextEditingController();

  List<StudyCourse> _courses = [];

  @override
  void dispose() {
    _arLevelCtrl.dispose();
    _enLevelCtrl.dispose();
    super.dispose();
  }

  List<PlanTrackOption> get _tracks {
    if (_selectedProgramId == null) return [];
    try {
      final prog = widget.viewModel.programs
          .firstWhere((p) => p.id == _selectedProgramId);
      return prog.tracks
          .map((t) => PlanTrackOption(id: t.trackId, name: t.nameAr))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _addCourse() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CourseFormDialog(
        nextOrder: _courses.length + 1,
        onSave: (c) => setState(() => _courses.add(c)),
      ),
    );
  }

  void _editCourse(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CourseFormDialog(
        existing: _courses[index],
        nextOrder: index + 1,
        onSave: (c) => setState(() => _courses[index] = c),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramId == null) {
      _snack('يرجى اختيار البرنامج', Colors.orange);
      return;
    }
    if (_selectedSemester == null) {
      _snack('يرجى اختيار الفصل الدراسي', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    final plan = StudyPlanModel(
      id: widget.viewModel.generateId(),
      programId: _selectedProgramId!,
      trackId:
          (_selectedTrackId == null || _selectedTrackId!.isEmpty)
              ? null
              : _selectedTrackId,
      arLevel: _arLevelCtrl.text.trim(),
      enLevel: _enLevelCtrl.text.trim(),
      arSemester: _selectedSemester!.arLabel,
      enSemester: _selectedSemester!.enLabel,
      semesterTotals: SemesterTotals.empty(),
      courses: _courses,
      createdAt: DateTime.now(),
    );

    await widget.viewModel.addPlan(plan);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تمت إضافة الخطة الدراسية بنجاح'),
          backgroundColor: Colors.green));
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.viewModel.programs;
    final tracks = _tracks;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة خطة دراسية جديدة',
                      style: DesktopTextStyles.heading2),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: DesktopSpacing.md),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── البرنامج ───────────────────────────────────────
                      const PlanSectionTitle('البرنامج الأكاديمي'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedProgramId,
                        decoration:
                            _dec('البرنامج الأكاديمي', Icons.school_outlined),
                        items: programs
                            .map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.nameAr)))
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedProgramId = val;
                          _selectedTrackId = null;
                        }),
                        validator: (v) => v == null ? 'اختر البرنامج' : null,
                      ),

                      if (tracks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedTrackId,
                          decoration: _dec(
                              'المسار (اختياري)', Icons.alt_route_outlined),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('الخطة العامة')),
                            ...tracks.map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedTrackId = val),
                        ),
                      ],

                      const SizedBox(height: DesktopSpacing.lg),

                      // ── المستوى ────────────────────────────────────────
                      const PlanSectionTitle('المستوى الدراسي'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _tf(
                                'المستوى (عربي، مثال: السنة الأولى)',
                                _arLevelCtrl,
                                Icons.layers_outlined)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _tf('المستوى (إنجليزي، مثال: First Year)',
                                _enLevelCtrl, Icons.layers_outlined)),
                      ]),

                      const SizedBox(height: DesktopSpacing.lg),

                      // ── الفصل الدراسي (Dropdown) ───────────────────────
                      const PlanSectionTitle('الفصل الدراسي'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SemesterOption>(
                        value: _selectedSemester,
                        decoration: _dec(
                            'اختر الفصل الدراسي',
                            Icons.calendar_today_outlined),
                        items: kSemesters
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                      '${s.arLabel}  •  ${s.enLabel}',
                                      style:
                                          const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSemester = v),
                        validator: (v) =>
                            v == null ? 'اختر الفصل الدراسي' : null,
                      ),

                      const SizedBox(height: DesktopSpacing.lg),

                      // ── المقررات ───────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PlanSectionTitle('المقررات الدراسية (${_courses.length})'),
                          TextButton.icon(
                            onPressed: _addCourse,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مقرر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _courses.isEmpty
                          ? _emptyBox()
                          : PlanCoursesTable(
                              courses: _courses,
                              onEdit: _editCourse,
                              onDelete: (i) =>
                                  setState(() => _courses.removeAt(i)),
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: DesktopSpacing.md),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: DesktopButtonTheme.elevatedButtonTheme.style,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ الخطة'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(String label, TextEditingController c, IconData icon) =>
      TextFormField(
        controller: c,
        validator: (v) => v!.isEmpty ? 'مطلوب' : null,
        decoration: _dec(label, icon),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  Widget _emptyBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DesktopColors.border)),
        child: const Center(
            child: Text('لا توجد مقررات مضافة بعد',
                style: TextStyle(color: Colors.grey))),
      );
}


