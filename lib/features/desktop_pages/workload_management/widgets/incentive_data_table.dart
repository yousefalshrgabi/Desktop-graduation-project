import 'package:flutter/material.dart';

import '../models/incentive_entry.dart';

/// Excel-like table for teacher incentive rows.
class IncentiveDataTable extends StatelessWidget {
  const IncentiveDataTable({
    super.key,
    required this.entries,
    this.sourceDepartmentHeader = 'قسم النتيجة',
  });

  final List<IncentiveEntry> entries;
  final String sourceDepartmentHeader;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
    }

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: double.infinity,
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: theme.dividerColor),
                  ),
                  columns: [
                    DataColumn(label: Text('م', style: headerStyle)),
                    DataColumn(label: Text('المعلم', style: headerStyle)),
                    DataColumn(label: Text('المادة', style: headerStyle)),
                    DataColumn(label: Text('نظري', style: headerStyle)),
                    DataColumn(label: Text('عملي', style: headerStyle)),
                    DataColumn(label: Text('إشراف عملي', style: headerStyle)),
                    DataColumn(label: Text('القسم', style: headerStyle)),
                    DataColumn(label: Text('المستوى', style: headerStyle)),
                    DataColumn(
                      label: Text(sourceDepartmentHeader, style: headerStyle),
                    ),
                  ],
                  rows: [
                    for (var i = 0; i < entries.length; i++)
                      _row(theme, i + 1, entries[i]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _row(ThemeData theme, int index, IncentiveEntry e) {
    Text cell(String text) => Text(
          text.isEmpty ? '—' : text,
          style: theme.textTheme.bodySmall,
        );

    return DataRow(
      cells: [
        DataCell(cell('$index')),
        DataCell(cell(e.teacherName)),
        DataCell(cell(e.subject)),
        DataCell(cell(_fmt(e.theoryHours))),
        DataCell(cell(_fmt(e.practicalHours))),
        DataCell(cell(_fmt(e.supervisionHours))),
        DataCell(cell(e.courseDepartment)),
        DataCell(cell(e.level)),
        DataCell(cell(e.sourceDepartment)),
      ],
    );
  }

  static String _fmt(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
