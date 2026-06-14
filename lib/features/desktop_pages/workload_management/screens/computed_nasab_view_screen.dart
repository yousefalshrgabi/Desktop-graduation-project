import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

import '../models/faculty_option.dart';
import '../models/incentive_entry.dart';
import '../services/computed_nasab_print_service.dart';
import '../services/computed_nasab_service.dart';
import '../services/faculty_firestore_service.dart';
import '../services/incentive_word_export_service.dart';
import '../utils/nasab_department_filter.dart';
import '../widgets/incentive_data_table.dart';

/// Nasab computed from course assignments, study plans, and lab group settings.
class ComputedNasabViewScreen extends StatefulWidget {
  const ComputedNasabViewScreen({
    super.key,
    this.initialCollege = 'كلية الحاسبات',
    this.initialTerm = 'first',
    this.lockCollege = false,
  });

  final String initialCollege;
  final String initialTerm;
  final bool lockCollege;

  @override
  State<ComputedNasabViewScreen> createState() =>
      _ComputedNasabViewScreenState();
}

class _ComputedNasabViewScreenState extends State<ComputedNasabViewScreen> {
  final _nasabService = ComputedNasabService();
  final _wordExport = IncentiveWordExportService();
  final _printService = ComputedNasabPrintService();
  final _facultyService = FacultyFirestoreService();
  final _collegeController = TextEditingController();

  String _term = 'first';
  bool _loading = false;
  bool _exportingWord = false;
  bool _printing = false;
  List<IncentiveEntry> _entries = [];
  Map<String, String> _deptByTeacherName = {};

  String? _teacherFilter;
  String? _departmentFilter;
  String? _programFilter;

  @override
  void initState() {
    super.initState();
    _collegeController.text = widget.initialCollege;
    _term = widget.initialTerm;
    _load();
  }

  @override
  void dispose() {
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      final college = _collegeController.text.trim();
      final results = await Future.wait([
        _nasabService.buildEntries(
          collegeName: college,
          term: _term,
          forceRefresh: forceRefresh,
        ),
        widget.lockCollege
            ? _facultyService.listByCollege(
                college,
                forceRefresh: forceRefresh,
              )
            : _facultyService.listUniversityWide(forceRefresh: forceRefresh),
      ]);
      if (!mounted) return;
      final faculty = results[1] as List<FacultyOption>;
      setState(() {
        _entries = results[0] as List<IncentiveEntry>;
        _deptByTeacherName = NasabDepartmentFilter.deptByTeacherName(faculty);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر بناء النصاب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<IncentiveEntry> _filtered() {
    var list = NasabDepartmentFilter.filterEntries(
      all: _entries,
      deptByName: _deptByTeacherName,
      departmentFilter: _departmentFilter,
    );

    return list.where((e) {
      if (_teacherFilter != null &&
          e.teacherName.trim() != _teacherFilter!.trim()) {
        return false;
      }
      if (_programFilter != null &&
          e.courseDepartment.trim() != _programFilter!.trim()) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _unique(Iterable<String> values) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _exportWord(List<IncentiveEntry> all) async {
    final teacher = _teacherFilter;
    if (teacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مدرساً واحداً من الفلتر للتصدير')),
      );
      return;
    }
    setState(() => _exportingWord = true);
    try {
      await _wordExport.exportTeacherNasab(
        teacherName: teacher,
        entries: all,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير نصاب المدرس إلى Word')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التصدير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingWord = false);
    }
  }

  Future<void> _print(List<IncentiveEntry> filtered) async {
    setState(() => _printing = true);
    try {
      final termLabel = _term == 'first' ? 'الفصل الأول' : 'الفصل الثاني';
      await _printService.printEntries(
        title: 'نصاب محسوب — ${_collegeController.text.trim()} — $termLabel',
        entries: _entries,
        teacherFilter: _teacherFilter,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ ملف PDF بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الطباعة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final teachers = _unique(_entries.map((e) => e.teacherName));
    final departments = _deptByTeacherName.values
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final programs = _unique(_entries.map((e) => e.courseDepartment));

    final totalTheory = filtered.fold<double>(0, (s, e) => s + e.theoryHours);
    final totalPractical =
        filtered.fold<double>(0, (s, e) => s + e.practicalHours);
    final totalSupervision =
        filtered.fold<double>(0, (s, e) => s + e.supervisionHours);

    return Scaffold(
      appBar: SharedDesktopAppBar(
        customTitle: 'النصاب المحسوب',
        extraActions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'يُبنى من ربط المقررات + الخطط الدراسية + مجموعات العملي. '
                      'قسم المدرس من بيانات هيئة التدريس.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      tooltip: 'تحديث',
                      onPressed: _loading ? null : () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _collegeController,
                  readOnly: widget.lockCollege,
                  decoration: const InputDecoration(
                    labelText: 'الكلية',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: widget.lockCollege
                      ? null
                      : (_) => _load(forceRefresh: true),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'first', label: Text('الفصل الأول')),
                    ButtonSegment(value: 'second', label: Text('الفصل الثاني')),
                  ],
                  selected: {_term},
                  onSelectionChanged: _loading
                      ? null
                      : (s) {
                          setState(() => _term = s.first);
                          _load(forceRefresh: true);
                        },
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لا توجد بيانات.\n'
                    'تأكد من رفع الخطط، ضبط مجموعات العملي، وربط المدرسين بالمقررات.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            )
          else ...[
            if (_departmentFilter != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'فلتر قسم المدرس: يعرض كل مواد المدرسين في «$_departmentFilter» بغض النظر عن التخصص.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _teacherFilter,
                      decoration: const InputDecoration(
                        labelText: 'المدرس',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...teachers.map(
                          (t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _teacherFilter = v),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _departmentFilter,
                      decoration: const InputDecoration(
                        labelText: 'قسم المدرس',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...departments.map(
                          (d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _departmentFilter = v),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: _programFilter,
                      decoration: const InputDecoration(
                        labelText: 'التخصص',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...programs.map(
                          (p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _programFilter = v),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exportingWord || _teacherFilter == null
                        ? null
                        : () => _exportWord(_entries),
                    icon: _exportingWord
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined, size: 20),
                    label: const Text('تصدير Word'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _printing || filtered.isEmpty
                        ? null
                        : () => _print(filtered),
                    icon: _printing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded, size: 20),
                    label: const Text('طباعة PDF'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  _SummaryChip(label: 'السجلات', value: '${filtered.length}'),
                  _SummaryChip(
                    label: 'نظري',
                    value: totalTheory.toStringAsFixed(0),
                  ),
                  _SummaryChip(
                    label: 'عملي',
                    value: totalPractical.toStringAsFixed(0),
                  ),
                  _SummaryChip(
                    label: 'إشراف',
                    value: totalSupervision.toStringAsFixed(0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد نتائج لهذا الفلتر'))
                  : IncentiveDataTable(
                      entries: filtered,
                      sourceDepartmentHeader: 'قسم المدرس',
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
