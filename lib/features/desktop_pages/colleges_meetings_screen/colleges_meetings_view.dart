import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import 'package:academic_affairs_management/features/mobile_pages/meetings/meeting_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'colleges_meetings_view_model.dart';
import 'package:academic_affairs_management/core/widgets/searchable_user_dropdown.dart';

class CollegesMeetingsView extends StatefulWidget {
  const CollegesMeetingsView({super.key});

  @override
  State<CollegesMeetingsView> createState() => _CollegesMeetingsViewState();
}

class _CollegesMeetingsViewState extends State<CollegesMeetingsView> {
  final CollegesMeetingsViewModel _viewModel = CollegesMeetingsViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDocument(String? documentUrl) async {
    if (documentUrl == null || documentUrl.isEmpty) return;
    final url = Uri.parse(documentUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح رابط الملف.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: const SharedDesktopAppBar(
          customTitle: 'محاضر اجتماعات الكليات والأقسام'),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return Padding(
            padding: const EdgeInsets.all(DesktopSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: DesktopSpacing.lg),
                _buildFilters(context),
                const SizedBox(height: DesktopSpacing.md),
                Expanded(child: _buildMeetingsContent()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('محاضر اجتماعات الكليات والأقسام',
            style: DesktopTextStyles.heading1),
        const SizedBox(height: DesktopSpacing.xs / 2),
        Text(
          'استعراض ومتابعة محاضر الاجتماعات المرفوعة من الكليات والأقسام العلمية (عرض فقط)',
          style: DesktopTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesktopSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: Row(
        children: [
          // 1. Search text
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _viewModel.updateSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الاجتماع أو القسم...',
                prefixIcon: const Icon(Icons.search),
                enabledBorder:
                    DesktopInputTheme.inputDecorationTheme.enabledBorder,
                focusedBorder:
                    DesktopInputTheme.inputDecorationTheme.focusedBorder,
              ),
            ),
          ),
          const SizedBox(width: DesktopSpacing.md),

          // 2. College filter
          Expanded(
            child: SearchableUserDropdown(
              value: _viewModel.selectedCollege,
              defaultName: 'الكل',
              items: _viewModel.colleges,
              hint: 'تصفية حسب الكلية',
              onChanged: (val) => _viewModel.updateSelectedCollege(val),
            ),
          ),
          const SizedBox(width: DesktopSpacing.md),

          // 3. Refresh button
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh, color: DesktopColors.primary),
            onPressed: () => _viewModel.loadData(),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsContent() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          _viewModel.errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    final meetings = _viewModel.filteredMeetings;
    if (meetings.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد محاضر اجتماعات تطابق خيارات التصفية.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CustomDataTable(
              columns: const [
                DataColumn(
                    label: Text('المعرف', style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('عنوان الاجتماع',
                        style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('الكلية', style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('القسم', style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('التاريخ والوقت',
                        style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('المحضر المرفوع',
                        style: DesktopTextStyles.caption)),
                DataColumn(
                    label: Text('إجراءات', style: DesktopTextStyles.caption)),
              ],
              rows: meetings.map((meeting) {
                return DataRow(cells: [
                  DataCell(Text('#${meeting.id.substring(0, 5)}...',
                      style: DesktopTextStyles.caption)),
                  DataCell(Text(meeting.title, style: DesktopTextStyles.body)),
                  DataCell(
                      Text(meeting.college, style: DesktopTextStyles.body)),
                  DataCell(Text(meeting.departmentId, style: DesktopTextStyles.body)),
                  DataCell(Text('${meeting.date} - ${meeting.time}',
                      style: DesktopTextStyles.body)),
                  DataCell(
                    meeting.documentUrl != null &&
                            meeting.documentUrl!.isNotEmpty
                        ? TextButton.icon(
                            onPressed: () => _openDocument(meeting.documentUrl),
                            icon: const Icon(Icons.download_for_offline,
                                size: 18),
                            label: const Text('تحميل المستند'),
                          )
                        : const Text('لا يوجد ملف مرفوع',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showDetailsDialog(context, meeting),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('عرض التفاصيل'),
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, MeetingModel meeting) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 700,
            height: 650,
            padding: const EdgeInsets.all(DesktopSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تفاصيل اجتماع: ${meeting.title}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
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
                Expanded(
                  child: ListView(
                    children: [
                      // Basic Info
                      _buildDetailRow('الكلية', meeting.college),
                      _buildDetailRow('القسم', meeting.departmentId),
                      _buildDetailRow('التاريخ', meeting.date),
                      _buildDetailRow('الوقت', meeting.time),
                      _buildDetailRow('مكان الاجتماع',
                          meeting.room.isNotEmpty ? meeting.room : 'غير محدد'),
                      _buildDetailRow(
                          'حالة الاجتماع', meeting.status.displayName),
                      if (meeting.rejectReason != null &&
                          meeting.rejectReason!.isNotEmpty)
                        _buildDetailRow(
                            'سبب الرفض/التعديل', meeting.rejectReason!,
                            isWarning: true),
                      const SizedBox(height: DesktopSpacing.md),

                      // Attendees
                      const Text(
                        'أعضاء هيئة التدريس الحاضرين:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: DesktopSpacing.xs),
                      if (meeting.attendees.isEmpty)
                        const Text('لا يوجد أعضاء مسجلين',
                            style: TextStyle(color: Colors.grey))
                      else
                        Container(
                          padding: const EdgeInsets.all(DesktopSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: BulletList(items: meeting.attendees),
                        ),
                      const SizedBox(height: DesktopSpacing.md),

                      // Agenda
                      const Text(
                        'جدول أعمال الاجتماع:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: DesktopSpacing.xs),
                      if (meeting.agenda.isEmpty)
                        const Text('لا يوجد جدول أعمال',
                            style: TextStyle(color: Colors.grey))
                      else
                        Container(
                          padding: const EdgeInsets.all(DesktopSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: BulletList(items: meeting.agenda),
                        ),
                      const SizedBox(height: DesktopSpacing.md),

                      // Minutes Text
                      const Text(
                        'نص محضر الاجتماع والقرارات المتخذة:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: DesktopSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(DesktopSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          meeting.minutes.isNotEmpty
                              ? meeting.minutes
                              : 'لم يتم كتابة تفاصيل المحضر بعد.',
                          style: const TextStyle(
                              fontSize: 14, height: 1.5, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesktopSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (meeting.documentUrl != null &&
                        meeting.documentUrl!.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesktopColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _openDocument(meeting.documentUrl),
                        icon: const Icon(Icons.download_for_offline),
                        label:
                            const Text('تحميل المحضر المرفوع (.docx / .pdf)'),
                      ),
                    const SizedBox(width: DesktopSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إغلاق'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontFamily: 'Cairo'),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWarning ? Colors.red : DesktopColors.textPrimary,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  final List<String> items;

  const BulletList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                item,
                style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
