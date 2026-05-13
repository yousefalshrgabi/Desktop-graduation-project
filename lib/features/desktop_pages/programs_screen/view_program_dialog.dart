import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'programs_model.dart';
import 'programs_viewmodel.dart';

class ViewProgramDialog extends StatelessWidget {
  final ProgramModel program;
  final ProgramsViewModel viewModel;

  const ViewProgramDialog(
      {super.key, required this.program, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'تفاصيل البرنامج الأكاديمي',
                        style: DesktopTextStyles.heading2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: DesktopSpacing.md),
                _buildDetailRow('اسم البرنامج (عربي):', program.nameAr),
                const SizedBox(height: 8),
                _buildDetailRow('اسم البرنامج (إنجليزي):', program.nameEn),
                const SizedBox(height: 8),
                _buildDetailRow(
                    'إجمالي المستويات:', program.totalLevels.toString()),
                const SizedBox(height: 8),
                _buildDetailRow(
                    'حالة المزامنة:',
                    program.isSynced
                        ? 'متزامن (Cloud)'
                        : 'غير متزامن (مخزن محلياً)'),
                const SizedBox(height: DesktopSpacing.lg),
                const Text('مسارات البرنامج:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                program.tracks.isEmpty
                    ? const Text('لا توجد مسارات مخصصة لهذا البرنامج',
                        style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: program.tracks.length,
                        itemBuilder: (context, index) {
                          final track = program.tracks[index];
                          return ListTile(
                            leading: const Icon(Icons.alt_route,
                                color: DesktopColors.primary),
                            title: Text(track.nameAr),
                            subtitle: Text(
                                '${track.nameEn} • من مستوى: ${track.startsAtLevel}'),
                          );
                        },
                      ),
                const SizedBox(height: DesktopSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(
          child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
