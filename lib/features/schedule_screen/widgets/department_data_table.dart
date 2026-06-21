import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../utils/timetable_schedule_grid.dart';

class DepartmentDataTable extends StatelessWidget {
  const DepartmentDataTable({
    super.key,
    required this.entries,
    required this.groups,
  });

  final List<TimetableEntry> entries;
  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty || groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد حصص للعرض',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final days = TimetableScheduleGrid.sortedDays(entries.map((e) => e.day));
    final hours = TimetableScheduleGrid.sortedHours(entries.map((e) => e.hour));

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
                  dataRowMinHeight: 48.0,
                  dataRowMaxHeight: double.infinity,
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: theme.dividerColor),
                  ),
                  columns: [
                    DataColumn(label: Text('اليوم', style: headerStyle)),
                    DataColumn(label: Text('المستوى/القسم', style: headerStyle)),
                    ...hours.map(
                      (h) => DataColumn(label: Text(h, style: headerStyle)),
                    ),
                  ],
                  rows: [
                    for (final day in days)
                      for (int gIdx = 0; gIdx < groups.length; gIdx++)
                        DataRow(
                          cells: [
                            DataCell(
                              gIdx == 0
                                  ? Text(
                                      day,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            DataCell(
                              Text(
                                groups[gIdx],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...hours.map((h) {
                              final cellEntries = entries
                                  .where((e) =>
                                      e.day == day &&
                                      e.hour == h &&
                                      e.studentSets.contains(groups[gIdx]))
                                  .toList();
                              return DataCell(
                                _DepartmentCellBody(cellEntries),
                              );
                            }),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DepartmentCellBody extends StatelessWidget {
  const _DepartmentCellBody(this.entries);

  final List<TimetableEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.black38));
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.subject,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (e.teachers.isNotEmpty)
                      Text(
                        e.teachers.join('، '),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (e.room.isNotEmpty)
                      Text(
                        e.room,
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
