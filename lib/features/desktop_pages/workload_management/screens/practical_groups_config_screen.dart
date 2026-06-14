import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';

import '../models/practical_group_setting.dart';
import '../services/practical_group_firestore_service.dart';
import '../utils/level_labels.dart';
import '../utils/practical_hours_calculator.dart';

/// Configure student lab groups per specialization (program) and level.
class PracticalGroupsConfigScreen extends StatefulWidget {
  const PracticalGroupsConfigScreen({
    super.key,
    this.initialCollege = 'كلية الحاسبات',
    this.canEdit = false,
    this.lockCollege = false,
  });

  final String initialCollege;
  final bool canEdit;
  final bool lockCollege;

  @override
  State<PracticalGroupsConfigScreen> createState() =>
      _PracticalGroupsConfigScreenState();
}

class _PracticalGroupsConfigScreenState
    extends State<PracticalGroupsConfigScreen> {
  final _service = PracticalGroupFirestoreService();
  final _collegeController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  List<ProgramLevelPracticalRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _collegeController.text = widget.initialCollege;
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
      final rows = await _service.loadRows(
        collegeName: _collegeController.text.trim(),
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر التحميل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    setState(() => _saving = true);
    try {
      await _service.saveAll(
        collegeName: _collegeController.text.trim(),
        rows: _rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات المجموعات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setGroupCount(int index, int count) {
    if (!widget.canEdit) return;
    setState(() {
      _rows[index] = _rows[index].copyWith(groupCount: count);
    });
  }

  void _toggleParallelGroup(int rowIndex, int groupIndex) {
    if (!widget.canEdit) return;
    setState(() {
      final row = _rows[rowIndex];
      final currentIndices = List<int>.from(row.parallelGroupIndices);

      if (currentIndices.contains(groupIndex)) {
        currentIndices.remove(groupIndex);
      } else {
        currentIndices.add(groupIndex);
      }

      _rows[rowIndex] = row.copyWith(parallelGroupIndices: currentIndices);
    });
  }

  Map<String, List<ProgramLevelPracticalRow>> _groupedByProgram() {
    final map = <String, List<ProgramLevelPracticalRow>>{};
    for (final row in _rows) {
      map.putIfAbsent(row.programName, () => []).add(row);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byProgram = _groupedByProgram();

    return Scaffold(
      appBar: SharedDesktopAppBar(
        customTitle: 'مجموعات العملي',
        extraActions: [
          IconButton(
            tooltip: 'تحديث من السحابة',
            onPressed:
                _loading || _saving ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.cloud_download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _collegeController,
                  readOnly: widget.lockCollege || !widget.canEdit,
                  decoration: const InputDecoration(
                    labelText: 'الكلية',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  onSubmitted: widget.lockCollege || !widget.canEdit
                      ? null
                      : (_) => _load(forceRefresh: true),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _load(forceRefresh: true),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('تحميل التخصصات والمستويات من الخطط'),
                ),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'يُستخرج التخصص (البرنامج) والمستوى من الخطط الدراسية المرفوعة. '
                      'كل محاضرة عملي وزنها ${PracticalHoursCalculator.lectureHours} ساعات. '
                      'ساعات العملي في ملف الانصبة للمادة ≈ عدد المجموعات × ساعات العملي للمجموعة الواحدة من الخطة '
                      '(مثال: علوم الحاسوب المستوى الثاني → 4 ساعات = مجموعتان؛ '
                      'تقنية المعلومات المستوى الثاني → 6 ساعات = 3 مجموعات).',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لا توجد مواد عملية في الخطط المرفوعة لهذه الكلية.\n'
                            'ارفع الخطط الدراسية أولاً من شاشة «الخطط الدراسية».',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        children: [
                          for (final entry in byProgram.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(
                                entry.key,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final tracks = entry.value
                                    .expand((r) => r.trackNames)
                                    .toSet()
                                    .toList()
                                  ..sort();
                                if (tracks.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'مسارات: ${tracks.join('، ')}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                            ...entry.value.map((row) {
                              final globalIndex = _rows.indexOf(row);
                              final h = row.typicalHoursPerGroup;
                              final estNasab =
                                  PracticalHoursCalculator.nasabHoursForCourse(
                                practicalHoursPerGroup: h,
                                groupCount: row.groupCount,
                              );
                              final sessions = PracticalHoursCalculator
                                  .totalSessionsForCourse(
                                practicalHoursPerGroup: h,
                                groupCount: row.groupCount,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        LevelLabels.forLevel(row.level),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${row.practicalCourseCount} مادة تحوي عملي '
                                        '• $h ساعة/مجموعة للمادة النموذجية',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text('عدد المجموعات:'),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            onPressed: widget.canEdit &&
                                                    row.groupCount > 1
                                                ? () => _setGroupCount(
                                                      globalIndex,
                                                      row.groupCount - 1,
                                                    )
                                                : null,
                                            icon: const Icon(
                                                Icons.remove_circle_outline),
                                          ),
                                          Text(
                                            '${row.groupCount}',
                                            style:
                                                theme.textTheme.headlineSmall,
                                          ),
                                          IconButton(
                                            onPressed: widget.canEdit &&
                                                    row.groupCount < 12
                                                ? () => _setGroupCount(
                                                      globalIndex,
                                                      row.groupCount + 1,
                                                    )
                                                : null,
                                            icon: const Icon(
                                                Icons.add_circle_outline),
                                          ),
                                          const Spacer(),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '≈ $estNasab ساعة/مادة',
                                                style:
                                                    theme.textTheme.labelLarge,
                                              ),
                                              Text(
                                                '$sessions محاضرة عملي',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (row.groupCount > 1) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          'تحديد المجموعات الموازي:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: List.generate(
                                              row.groupCount, (i) {
                                            final groupIndex = i + 1;
                                            final isParallel = row
                                                .parallelGroupIndices
                                                .contains(groupIndex);
                                            return FilterChip(
                                              label: Text('مجموعة $groupIndex'),
                                              selected: isParallel,
                                              onSelected: widget.canEdit
                                                  ? (selected) {
                                                      _toggleParallelGroup(
                                                          globalIndex,
                                                          groupIndex);
                                                    }
                                                  : null,
                                              selectedColor:
                                                  Colors.orange.shade100,
                                              checkmarkColor:
                                                  Colors.orange.shade700,
                                            );
                                          }),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: _rows.isEmpty || !widget.canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الإعدادات'),
            ),
    );
  }
}
