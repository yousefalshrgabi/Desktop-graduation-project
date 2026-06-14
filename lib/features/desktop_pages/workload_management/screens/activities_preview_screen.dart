import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import '../models/activity_schedule_row.dart';
import '../services/activities_schedule_service.dart';

/// Preview Activities export before saving Excel file.
class ActivitiesPreviewScreen extends StatefulWidget {
  const ActivitiesPreviewScreen({
    super.key,
    required this.collegeName,
    required this.term,
    required this.rows,
  });

  final String collegeName;
  final String term;
  final List<ActivityScheduleRow> rows;

  @override
  State<ActivitiesPreviewScreen> createState() =>
      _ActivitiesPreviewScreenState();
}

class _ActivitiesPreviewScreenState extends State<ActivitiesPreviewScreen> {
  final _exportService = ActivitiesScheduleService();
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _exportService.exportToExcel(
        collegeName: widget.collegeName,
        term: widget.term,
        rows: widget.rows,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير ملف Activities بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر التصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: SharedDesktopAppBar(
        customTitle: 'جدول الفعاليات (Activities)',
        extraActions: [
          IconButton(
            tooltip: 'تصدير Excel',
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.rows.length} صف — نفس أعمدة ورقة Activities: '
                    'المجموعة، المادة، المعلم',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'تصدير Excel',
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      notificationPredicate: (n) => n.depth == 1,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              theme.colorScheme.surfaceContainerHighest,
                            ),
                            columns: [
                              DataColumn(
                                label: Text('Students Sets', style: headerStyle),
                              ),
                              DataColumn(
                                label: Text('Subject', style: headerStyle),
                              ),
                              DataColumn(
                                label: Text('Teachers', style: headerStyle),
                              ),
                            ],
                            rows: [
                              for (final r in widget.rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text(r.studentSet)),
                                    DataCell(Text(r.subject)),
                                    DataCell(Text(r.teacher)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.table_view_rounded),
                label: Text(
                  _exporting
                      ? 'جاري التصدير...'
                      : 'تصدير ملف Excel (Activities)',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
