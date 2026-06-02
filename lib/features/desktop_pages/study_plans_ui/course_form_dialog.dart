import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'study_plans_model.dart';

// ─── خيارات نوع المقرر ─────────────────────────────────────────────────────
class CourseTypeOption {
  final String arLabel;
  final String enLabel;
  const CourseTypeOption(this.arLabel, this.enLabel);
}

const List<CourseTypeOption> kCourseTypes = [
  CourseTypeOption('متطلب جامعة', 'University Requirement'),
  CourseTypeOption('متطلب كلية', 'College Requirement'),
  CourseTypeOption('متطلب قسم', 'Department Requirement'),
];

// ─── خيارات الفصل الدراسي ──────────────────────────────────────────────────
class SemesterOption {
  final String arLabel;
  final String enLabel;
  const SemesterOption(this.arLabel, this.enLabel);
}

const List<SemesterOption> kSemesters = [
  SemesterOption('الفصل الأول', 'First Semester'),
  SemesterOption('الفصل الثاني', 'Second Semester'),
];

// ─── موديل بسيط للمادة الدراسية ────────────────────────────────────────────
class _SubjectItem {
  final String id;
  final String arName;
  final String enName;
  _SubjectItem({required this.id, required this.arName, required this.enName});
}

// ─── نافذة إضافة / تعديل مقرر ─────────────────────────────────────────────
class CourseFormDialog extends StatefulWidget {
  final StudyCourse? existing;
  final int nextOrder; // الترتيب التلقائي
  final void Function(StudyCourse) onSave;

  const CourseFormDialog({
    super.key,
    this.existing,
    required this.nextOrder,
    required this.onSave,
  });

  @override
  State<CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Subject search
  List<_SubjectItem> _allSubjects = [];
  List<_SubjectItem> _filteredSubjects = [];
  _SubjectItem? _selectedSubject;
  final _subjectSearchCtrl = TextEditingController();
  bool _loadingSubjects = true;

  // Course type
  CourseTypeOption? _selectedType;

  // Hours
  final _actThCtrl = TextEditingController(text: '0');
  final _actPrCtrl = TextEditingController(text: '0');
  final _credThCtrl = TextEditingController(text: '0');
  final _credPrCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    // Pre-fill if editing
    final e = widget.existing;
    if (e != null) {
      _subjectSearchCtrl.text = e.courseId;
      _selectedType = kCourseTypes.firstWhere(
        (t) => t.arLabel == e.arCourseType,
        orElse: () => kCourseTypes.first,
      );
      _actThCtrl.text = e.courseHours.actual.theoretical.toString();
      _actPrCtrl.text = e.courseHours.actual.practical.toString();
      _credThCtrl.text = e.courseHours.credit.theoretical.toString();
      _credPrCtrl.text = e.courseHours.credit.practical.toString();
    }
    _subjectSearchCtrl.addListener(_filterSubjects);
  }

  Future<void> _loadSubjects() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('subjects');
      _allSubjects = result
          .map((r) => _SubjectItem(
                id: r['id'].toString(),
                arName: r['ar_name']?.toString() ?? '',
                enName: r['en_name']?.toString() ?? '',
              ))
          .toList();
      _filteredSubjects = List.from(_allSubjects);

      // If editing, try to find the matching subject
      if (widget.existing != null) {
        try {
          _selectedSubject =
              _allSubjects.firstWhere((s) => s.id == widget.existing!.courseId);
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSubjects = false);
  }

  void _filterSubjects() {
    final q = _subjectSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredSubjects = q.isEmpty
          ? List.from(_allSubjects)
          : _allSubjects
              .where((s) =>
                  s.id.toLowerCase().contains(q) ||
                  s.arName.toLowerCase().contains(q) ||
                  s.enName.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _subjectSearchCtrl.dispose();
    _actThCtrl.dispose();
    _actPrCtrl.dispose();
    _credThCtrl.dispose();
    _credPrCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى اختيار نوع المقرر'),
          backgroundColor: Colors.orange));
      return;
    }

    final courseId = _selectedSubject?.id ?? _subjectSearchCtrl.text.trim();
    if (courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى اختيار أو كتابة رمز المادة'),
          backgroundColor: Colors.orange));
      return;
    }

    final ath = int.tryParse(_actThCtrl.text) ?? 0;
    final apr = int.tryParse(_actPrCtrl.text) ?? 0;
    final cth = int.tryParse(_credThCtrl.text) ?? 0;
    final cpr = int.tryParse(_credPrCtrl.text) ?? 0;

    widget.onSave(StudyCourse(
      courseId: courseId,
      courseOrder: widget.existing?.courseOrder ?? widget.nextOrder,
      arCourseType: _selectedType!.arLabel,
      enCourseType: _selectedType!.enLabel,
      courseHours: CourseHoursDetail(
        actual: CourseHours(theoretical: ath, practical: apr, total: ath + apr),
        credit: CourseHours(theoretical: cth, practical: cpr, total: cth + cpr),
      ),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing == null
                        ? 'إضافة مقرر دراسي'
                        : 'تعديل المقرر',
                    style: DesktopTextStyles.heading2,
                  ),
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
                      // ── اختيار المادة (بحث) ───────────────────────────
                      const _Label('المادة الدراسية'),
                      const SizedBox(height: 6),
                      _buildSubjectPicker(),

                      const SizedBox(height: DesktopSpacing.md),

                      // ── نوع المقرر ────────────────────────────────────
                      const _Label('نوع المقرر'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CourseTypeOption>(
                        value: _selectedType,
                        decoration:
                            _dec('اختر نوع المقرر', Icons.category_outlined),
                        items: kCourseTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.arLabel,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedType = v),
                        validator: (v) => v == null ? 'اختر نوع المقرر' : null,
                      ),

                      const SizedBox(height: DesktopSpacing.md),

                      // ── الترتيب التلقائي ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DesktopColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.format_list_numbered,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'ترتيب المادة في الخطة: ${widget.existing?.courseOrder ?? widget.nextOrder}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          const Text('(تلقائي)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        ]),
                      ),

                      const SizedBox(height: DesktopSpacing.md),

                      // ── الساعات الفعلية ───────────────────────────────
                      _HoursSection(
                        title: 'الساعات الفعلية',
                        color: Colors.blue,
                        thCtrl: _actThCtrl,
                        prCtrl: _actPrCtrl,
                      ),
                      const SizedBox(height: DesktopSpacing.md),

                      // ── الساعات المعتمدة ──────────────────────────────
                      _HoursSection(
                        title: 'الساعات المعتمدة',
                        color: DesktopColors.primary,
                        thCtrl: _credThCtrl,
                        prCtrl: _credPrCtrl,
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
                  onPressed: _save,
                  style: DesktopButtonTheme.elevatedButtonTheme.style,
                  child: const Text('حفظ المقرر'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectPicker() {
    if (_loadingSubjects) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          controller: _subjectSearchCtrl,
          decoration: InputDecoration(
            hintText: 'ابحث برمز المادة أو اسمها...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _subjectSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _subjectSearchCtrl.clear();
                      setState(() => _selectedSubject = null);
                    })
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (_subjectSearchCtrl.text.isNotEmpty && _selectedSubject == null) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: DesktopColors.border),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3))
              ],
            ),
            child: _filteredSubjects.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'لا توجد مادة بهذا الاسم — سيُستخدم "${_subjectSearchCtrl.text}" كرمز مباشر',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSubjects.length,
                    itemBuilder: (_, i) {
                      final s = _filteredSubjects[i];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSubject = s;
                            _subjectSearchCtrl.text = s.id;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
                            const Icon(Icons.book_outlined,
                                size: 16, color: DesktopColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.id,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Text('${s.arName} • ${s.enName}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
        if (_selectedSubject != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DesktopColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DesktopColors.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  size: 16, color: DesktopColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_selectedSubject!.id} — ${_selectedSubject!.arName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DesktopColors.primary,
                      fontSize: 13),
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _selectedSubject = null;
                  _subjectSearchCtrl.clear();
                }),
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );
}

// ─── ساعات ──────────────────────────────────────────────────────────────────
class _HoursSection extends StatelessWidget {
  final String title;
  final Color color;
  final TextEditingController thCtrl;
  final TextEditingController prCtrl;
  const _HoursSection(
      {required this.title,
      required this.color,
      required this.thCtrl,
      required this.prCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.access_time, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _numField('نظري', thCtrl, color)),
          const SizedBox(width: 12),
          Expanded(child: _numField('عملي', prCtrl, color)),
        ]),
      ]),
    );
  }

  Widget _numField(String label, TextEditingController ctrl, Color col) =>
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: col),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: col),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
}

// ─── كلاسات مساعدة مشتركة (عامة) ──────────────────────────────────────────

class PlanSectionTitle extends StatelessWidget {
  final String text;
  const PlanSectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
}

class PlanTrackOption {
  final String id;
  final String name;
  PlanTrackOption({required this.id, required this.name});
}

class PlanTableHeader extends StatelessWidget {
  final String text;
  const PlanTableHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
      );
}

class PlanTableCell extends StatelessWidget {
  final Widget child;
  const PlanTableCell(this.child, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: child,
      );
}

// جدول المقررات المضافة (مشترك بين Add و Edit)
class PlanCoursesTable extends StatelessWidget {
  final List<StudyCourse> courses;
  final void Function(int) onEdit;
  final void Function(int) onDelete;
  const PlanCoursesTable({
    super.key,
    required this.courses,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8)),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(2.6),
          3: FixedColumnWidth(52),
          4: FixedColumnWidth(52),
          5: FixedColumnWidth(52),
          6: FixedColumnWidth(52),
          7: FixedColumnWidth(72),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            children: const [
              PlanTableHeader('#'),
              PlanTableHeader('رمز المادة'),
              PlanTableHeader('النوع'),
              PlanTableHeader('ف.ن'),
              PlanTableHeader('ف.ع'),
              PlanTableHeader('م.ن'),
              PlanTableHeader('م.ع'),
              PlanTableHeader('إجراءات'),
            ],
          ),
          ...List.generate(courses.length, (i) {
            final c = courses[i];
            return TableRow(
              decoration: BoxDecoration(
                  color: i.isOdd ? Colors.grey[50] : Colors.white),
              children: [
                PlanTableCell(Text('${i + 1}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
                PlanTableCell(Text(c.courseId,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6750A4)))),
                PlanTableCell(Text(c.arCourseType,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
                PlanTableCell(Text('${c.courseHours.actual.theoretical}',
                    style: const TextStyle(fontSize: 12))),
                PlanTableCell(Text('${c.courseHours.actual.practical}',
                    style: const TextStyle(fontSize: 12))),
                PlanTableCell(Text('${c.courseHours.credit.theoretical}',
                    style: const TextStyle(fontSize: 12))),
                PlanTableCell(Text('${c.courseHours.credit.practical}',
                    style: const TextStyle(fontSize: 12))),
                PlanTableCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  InkWell(
                      onTap: () => onEdit(i),
                      child: const Icon(Icons.edit,
                          size: 15, color: Colors.orange)),
                  const SizedBox(width: 8),
                  InkWell(
                      onTap: () => onDelete(i),
                      child: const Icon(Icons.delete,
                          size: 15, color: Colors.red)),
                ])),
              ],
            );
          }),
        ],
      ),
    );
  }
}
