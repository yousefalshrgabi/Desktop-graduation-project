import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'workload_viewmodel.dart';

class WorkloadReportView extends StatelessWidget {
  const WorkloadReportView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkloadViewModel(),
      child: const _WorkloadReportContent(),
    );
  }
}

class _WorkloadReportContent extends StatelessWidget {
  const _WorkloadReportContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<WorkloadViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير النصاب التدريسي للأعضاء'),
        centerTitle: true,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildReportTable(viewModel, context),
    );
  }

  Widget _buildReportTable(WorkloadViewModel viewModel, BuildContext context) {
    final reports = viewModel.workloadReports.values.toList();

    if (reports.isEmpty) {
      return const Center(child: Text('لا توجد بيانات أنصبة محسوبة. قم بربط المقررات أولاً.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blueGrey.shade50),
              columns: const [
                DataColumn(label: Text('اسم العضو', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ساعات نظري', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ساعات عملي', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('إجمالي الساعات', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('النصاب القانوني', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('حالة النصاب', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('تعديل الحد', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: reports.map((report) {
                final isOverloaded = report.totalHours > report.workloadLimit;
                final extraHours = report.totalHours - report.workloadLimit;

                return DataRow(
                  cells: [
                    DataCell(Text(report.facultyMemberName)),
                    DataCell(Text(report.theoreticalHours.toString())),
                    DataCell(Text(report.practicalHours.toString())),
                    DataCell(Text(
                      report.totalHours.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOverloaded ? Colors.red : Colors.green,
                      ),
                    )),
                    DataCell(Text(report.workloadLimit.toString())),
                    DataCell(
                      isOverloaded
                          ? Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                Text('زائد بـ $extraHours ساعة', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const Text('طبيعي', style: TextStyle(color: Colors.green)),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () {
                          _showEditLimitDialog(context, viewModel, report);
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditLimitDialog(BuildContext context, WorkloadViewModel viewModel, TeacherWorkloadData report) {
    int newLimit = report.workloadLimit;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('تعديل النصاب لـ ${report.facultyMemberName}'),
          content: TextFormField(
            initialValue: newLimit.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الحد الأقصى للساعات', border: OutlineInputBorder()),
            onChanged: (val) => newLimit = int.tryParse(val) ?? report.workloadLimit,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                viewModel.updateWorkloadLimit(report.facultyMemberId, newLimit);
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }
}
