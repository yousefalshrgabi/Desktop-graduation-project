import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'mobile_my_schedule_view_model.dart';

class MobileMyScheduleView extends StatelessWidget {
  const MobileMyScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MobileMyScheduleViewModel>(
      create: (_) => MobileMyScheduleViewModel(),
      child: Consumer<MobileMyScheduleViewModel>(
        builder: (context, viewModel, child) {
          double totalTheory = 0;
          double totalPractical = 0;
          double totalSupervision = 0;

          for (var e in viewModel.myNasab) {
            totalTheory += e.theoryHours;
            totalPractical += e.practicalHours;
            totalSupervision += e.supervisionHours;
          }
          final totalHours = totalTheory + totalPractical + totalSupervision;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: const Color(0xFFF4F6F9),
              appBar: AppBar(
                title: const Text('نصابي الدراسي'),
                backgroundColor: DesktopColors.primary,
                foregroundColor: Colors.white,
                actions: [
                  if (!viewModel.loading && viewModel.myNasab.isNotEmpty)
                    viewModel.exporting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                          )
                        : PopupMenuButton<String>(
                            icon: const Icon(Icons.file_download_outlined),
                            tooltip: 'خيارات التصدير',
                            onSelected: (action) async {
                              bool success = await viewModel.exportData(action);
                              if (context.mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم تصدير النصاب المحسوب بنجاح')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(viewModel.errorMessage)),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'word',
                                child: Row(
                                  children: [
                                    Icon(Icons.description_outlined, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('تصدير كملف Word'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('طباعة كملف PDF'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                ],
              ),
              body: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'first', label: Text('الفصل الأول')),
                        ButtonSegment(value: 'second', label: Text('الفصل الثاني')),
                      ],
                      selected: {viewModel.term},
                      onSelectionChanged: viewModel.loading
                          ? null
                          : (s) => viewModel.setTerm(s.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return DesktopColors.primary.withValues(alpha: 0.1);
                            }
                            return Colors.white;
                          },
                        ),
                      ),
                    ),
                  ),

                  if (viewModel.loading)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('جاري حساب وجلب النصاب...'),
                          ],
                        ),
                      ),
                    )
                  else if (viewModel.errorMessage.isNotEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          viewModel.errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  else if (viewModel.myNasab.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد نصاب متاح للفصل المحدد.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(child: _buildSummaryCard('الإجمالي', totalHours.toStringAsFixed(1), Colors.blue)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildSummaryCard('نظري', totalTheory.toStringAsFixed(1), Colors.orange)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildSummaryCard('عملي', totalPractical.toStringAsFixed(1), Colors.green)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildSummaryCard('إشراف', totalSupervision.toStringAsFixed(1), Colors.purple)),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final entry = viewModel.myNasab[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.subject,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: DesktopColors.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              _buildDetailChip('التخصص', entry.courseDepartment, Icons.account_tree_outlined),
                                              const SizedBox(width: 8),
                                              _buildDetailChip('المستوى', entry.level, Icons.layers_outlined),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                            child: Divider(height: 1),
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildHourInfo('نظري', entry.theoryHours),
                                              _buildHourInfo('عملي', entry.practicalHours),
                                              _buildHourInfo('إشراف', entry.supervisionHours),
                                              _buildHourInfo('المجموع', entry.totalHours, isTotal: true),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                childCount: viewModel.myNasab.length,
                              ),
                            ),
                          ),
                          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color.shade900,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$label: $value',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourInfo(String label, double hours, {bool isTotal = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isTotal ? DesktopColors.primary : Colors.grey.shade600,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hours.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 16,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
            color: isTotal ? DesktopColors.primary : Colors.black87,
          ),
        ),
      ],
    );
  }
}
