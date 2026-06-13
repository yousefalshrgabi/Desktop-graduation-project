import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../utils/timetable_schedule_grid.dart';

/// Timetable-style grid: rows = days, columns = hour slots.
class TimetableDataTable extends StatefulWidget {
  const TimetableDataTable({
    super.key,
    required this.entries,
    this.showTeachers = true,
    this.showStudentSets = true,
    this.showRoom = true,
  });

  final List<TimetableEntry> entries;
  final bool showTeachers;
  final bool showStudentSets;
  final bool showRoom;

  @override
  State<TimetableDataTable> createState() => _TimetableDataTableState();
}

class _TimetableDataTableState extends State<TimetableDataTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
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

    final days = TimetableScheduleGrid.sortedDays(widget.entries.map((e) => e.day));
    final hours = TimetableScheduleGrid.sortedHours(widget.entries.map((e) => e.hour));

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalController,
          child: SingleChildScrollView(
            controller: _horizontalController,
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
                    DataColumn(
                      label: Text('اليوم', style: headerStyle),
                    ),
                    ...hours.map(
                      (h) => DataColumn(
                        label: Text(h, style: headerStyle),
                      ),
                    ),
                  ],
                  rows: days.map((day) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            day,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ...hours.map((hour) {
                          final cell = widget.entries
                              .where((e) => e.day == day && e.hour == hour)
                              .toList();
                          return DataCell(
                            _CellBody(
                              cell,
                              showTeachers: widget.showTeachers,
                              showStudentSets: widget.showStudentSets,
                              showRoom: widget.showRoom,
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CellBody extends StatelessWidget {
  const _CellBody(
    this.entries, {
    required this.showTeachers,
    required this.showStudentSets,
    required this.showRoom,
  });

  final List<TimetableEntry> entries;
  final bool showTeachers;
  final bool showStudentSets;
  final bool showRoom;

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
                color: theme.colorScheme.primaryContainer.withOpacity(0.35),
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
                    if (showTeachers && e.teachers.isNotEmpty)
                      Text(
                        e.teachers.join('، '),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (showStudentSets && e.studentSets.isNotEmpty)
                      Text(
                        e.studentSets.join(' + '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (showRoom && e.room.isNotEmpty)
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
