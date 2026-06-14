import 'package:flutter/material.dart';

import '../models/study_plan.dart';
import '../services/study_plan_firestore_service.dart';
import '../utils/level_labels.dart';
import '../widgets/study_plan_courses_editor.dart';
import '../widgets/study_plan_delete_dialog.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

class StudyPlanDetailScreen extends StatefulWidget {
  const StudyPlanDetailScreen({
    super.key,
    required this.planId,
    this.canEdit = false,
  });

  final String planId;
  final bool canEdit;

  @override
  State<StudyPlanDetailScreen> createState() => _StudyPlanDetailScreenState();
}

class _StudyPlanDetailScreenState extends State<StudyPlanDetailScreen> {
  final _service = StudyPlanFirestoreService();
  late Future<_DetailData> _future;
  final _searchController = TextEditingController();
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload({bool forceRefresh = false}) {
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final summary = await _service.getPlanSummary(widget.planId);
    final courses = await _service.getPlanCoursesRaw(widget.planId);
    return _DetailData(summary: summary, courses: courses);
  }

  Future<void> _deleteCurrentPlan(StudyPlanSummary summary) async {
    final confirmed = await confirmDeleteStudyPlan(context, summary);
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _service.deletePlan(widget.planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف خطة «${summary.displayTitle}»')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SharedDesktopAppBar(
        customTitle: 'تفاصيل الخطة',
        extraActions: [
          IconButton(
            onPressed: _deleting
                ? null
                : () => setState(() => _reload(forceRefresh: true)),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
          FutureBuilder<_DetailData>(
            future: _future,
            builder: (context, snap) {
              final summary = snap.data?.summary;
              if (summary == null) return const SizedBox.shrink();
              if (!widget.canEdit) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'حذف الخطة بالكامل',
                onPressed: _deleting ? null : () => _deleteCurrentPlan(summary),
                icon: Icon(Icons.delete_forever_rounded,
                    color: Colors.red.shade100),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<_DetailData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('خطأ: ${snap.error}'));
              }
              final data = snap.data;
              final summary = data?.summary;
              if (summary == null) {
                return const Center(child: Text('الخطة غير موجودة'));
              }

              final query = _searchController.text.trim().toLowerCase();
              final filtered = (data?.courses ?? []).where((row) {
                if (query.isEmpty) return true;
                final name = (row['nameAr'] ?? '').toString().toLowerCase();
                final code = (row['codeLocal'] ?? '').toString().toLowerCase();
                final en = (row['codeEn'] ?? '').toString().toLowerCase();
                return name.contains(query) ||
                    code.contains(query) ||
                    en.contains(query);
              }).toList();

              final grouped = <String, List<Map<String, dynamic>>>{};
              for (final row in filtered) {
                final key =
                    (row['semesterLabelAr'] ?? row['semesterKey'] ?? 'عام')
                        .toString();
                grouped.putIfAbsent(key, () => []).add(row);
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          summary.displayTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(summary.collegeName),
                        if (summary.trackStartSemester != null)
                          Text(
                            'يبدأ اختلاف المسار من ${LevelLabels.semesterLabel(summary.trackStartSemester!)}',
                          ),
                        if (summary.planStartYear != null)
                          Text('بداية الخطة: ${summary.planStartYear}'),
                        Text(
                          '${summary.courseCount} مقرر • ${summary.totalCreditHours} ساعة معتمدة',
                        ),
                        const SizedBox(height: 8),
                        if (widget.canEdit)
                          OutlinedButton.icon(
                            onPressed: _deleting
                                ? null
                                : () => _deleteCurrentPlan(summary),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('حذف هذه الخطة بالكامل'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade800,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'بحث في المقررات',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: grouped.isEmpty
                        ? const Center(child: Text('لا توجد مقررات مطابقة'))
                        : StudyPlanCoursesEditor(
                            planId: widget.planId,
                            groupedCourses: grouped,
                            canEdit: widget.canEdit,
                          ),
                  ),
                ],
              );
            },
          ),
          if (_deleting)
            const ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DetailData {
  const _DetailData({this.summary, this.courses = const []});
  final StudyPlanSummary? summary;
  final List<Map<String, dynamic>> courses;
}
