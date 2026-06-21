import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'mobile_faculty_profile_view_model.dart';

class MobileFacultyProfileView extends StatefulWidget {
  final Map<String, dynamic> facultyData;

  const MobileFacultyProfileView({super.key, required this.facultyData});

  @override
  State<MobileFacultyProfileView> createState() => _MobileFacultyProfileViewState();
}

class _MobileFacultyProfileViewState extends State<MobileFacultyProfileView> {
  late final MobileFacultyProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileFacultyProfileViewModel(facultyData: widget.facultyData);
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection() {
    String fileUrlStr = _viewModel.getString('file_url');
    if (fileUrlStr.isEmpty) return const Text('لا توجد ملفات مرفقة');

    try {
      Map<String, dynamic> urls = jsonDecode(fileUrlStr);
      List<Widget> fileWidgets = [];

      final categories = {
        'idCard': 'صورة الهوية / الجواز',
        'contract': 'العقد',
        'personalPhoto': 'صورة شخصية',
        'certificates': 'الشهادات',
        'others': 'ملفات أخرى'
      };

      urls.forEach((key, valueList) {
        if (valueList is List && valueList.isNotEmpty) {
          String catName = categories[key] ?? key;

          bool hasValidUrls = false;
          List<Widget> categoryWidgets = [];

          categoryWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(catName, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );

          for (int i = 0; i < valueList.length; i++) {
            String url = valueList[i].toString();
            if (url.isNotEmpty) {
              hasValidUrls = true;
              categoryWidgets.add(
                _FileItemWidget(
                  url: url,
                  title: 'ملف المرفق ${i + 1}',
                  viewModel: _viewModel,
                ),
              );
            }
          }

          if (hasValidUrls) {
            fileWidgets.addAll(categoryWidgets);
          }
        }
      });

      if (fileWidgets.isEmpty) return const Text('لا توجد ملفات مرفقة');
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: fileWidgets);
    } catch (e) {
      return const Text('خطأ في قراءة المرفقات');
    }
  }

  Widget _buildLeavesSection(String key, String title) {
    String leavesStr = _viewModel.getString(key);
    if (leavesStr.isEmpty) return const SizedBox.shrink();

    try {
      List<dynamic> leaves = jsonDecode(leavesStr);
      if (leaves.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...leaves.map((l) {
            Map<String, dynamic> leaf = l as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: leaf.entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
                ),
              ),
            );
          }),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MobileFacultyProfileViewModel>.value(
      value: _viewModel,
      child: Consumer<MobileFacultyProfileViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('الملف الشخصي: ${viewModel.getString('name')}'),
              centerTitle: true,
              backgroundColor: DesktopColors.primary,
              foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // البيانات الأساسية
                  _buildSectionHeader(context, 'البيانات الأساسية', Icons.person),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow('الاسم الكامل', viewModel.getString('name')),
                          _buildInfoRow('الرقم الوظيفي', viewModel.getString('job_number')),
                          _buildInfoRow('رقم الملف', viewModel.getString('file_number')),
                          _buildInfoRow('رقم الهوية', viewModel.getString('id_card_number')),
                          _buildInfoRow('مكان الميلاد', viewModel.getString('birth_place')),
                          _buildInfoRow('تاريخ الميلاد', viewModel.getString('birth_date')),
                          const Divider(),
                          _buildInfoRow('القسم', viewModel.getString('department', fallbackKey: 'user_dept')),
                          _buildInfoRow('التخصص العام', viewModel.getString('general_specialization')),
                          _buildInfoRow('التخصص الدقيق', viewModel.getString('exact_specialization')),
                          _buildInfoRow('حالة العضو', viewModel.getString('status')),
                        ],
                      ),
                    ),
                  ),

                  // التعيينات
                  _buildSectionHeader(context, 'تواريخ التعيين', Icons.work_history),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow('تاريخ أول تعيين', viewModel.getString('first_appointment_date')),
                          _buildInfoRow('تاريخ التعيين بالجامعة', viewModel.getString('university_appointment_date')),
                        ],
                      ),
                    ),
                  ),

                  // المؤهلات الأكاديمية
                  _buildSectionHeader(context, 'المؤهلات الأكاديمية', Icons.school),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('البكالوريوس', style: TextStyle(fontWeight: FontWeight.bold, color: DesktopColors.primary)),
                          _buildInfoRow('الدرجة', viewModel.getString('bsc_degree')),
                          _buildInfoRow('التاريخ', viewModel.getString('bsc_date')),
                          _buildInfoRow('الجامعة', viewModel.getString('bsc_university')),
                          _buildInfoRow('الدولة', viewModel.getString('bsc_country')),
                          _buildInfoRow('التخصص', viewModel.getString('bsc_specialization')),
                          const Divider(),
                          const Text('الماجستير', style: TextStyle(fontWeight: FontWeight.bold, color: DesktopColors.primary)),
                          _buildInfoRow('الدرجة', viewModel.getString('msc_degree')),
                          _buildInfoRow('التاريخ', viewModel.getString('msc_date')),
                          _buildInfoRow('الجامعة', viewModel.getString('msc_university')),
                          _buildInfoRow('الدولة', viewModel.getString('msc_country')),
                          _buildInfoRow('التخصص الدقيق', viewModel.getString('msc_exact_specialization')),
                          const Divider(),
                          const Text('الدرجة الحالية (دكتوراه وما يعادلها)', style: TextStyle(fontWeight: FontWeight.bold, color: DesktopColors.primary)),
                          _buildInfoRow('الدرجة', viewModel.getString('current_degree')),
                          _buildInfoRow('التاريخ', viewModel.getString('current_degree_date')),
                          _buildInfoRow('الجامعة', viewModel.getString('current_university')),
                          _buildInfoRow('الدولة', viewModel.getString('current_country')),
                        ],
                      ),
                    ),
                  ),

                  // الترقيات
                  _buildSectionHeader(context, 'الترقيات الأكاديمية', Icons.trending_up),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow('تاريخ أستاذ مساعد', viewModel.getString('assistant_prof_date')),
                          _buildInfoRow('رقم القرار', viewModel.getString('assistant_prof_decision')),
                          const Divider(),
                          _buildInfoRow('تاريخ أستاذ مشارك', viewModel.getString('assoc_prof_date')),
                          _buildInfoRow('رقم القرار', viewModel.getString('assoc_prof_decision')),
                          const Divider(),
                          _buildInfoRow('اللقب الأكاديمي الحالي', viewModel.getString('current_academic_title')),
                          _buildInfoRow('تاريخ نقل اللقب', viewModel.getString('title_transfer_date')),
                        ],
                      ),
                    ),
                  ),

                  // الإجازات
                  _buildSectionHeader(context, 'الإجازات الأكاديمية', Icons.event_busy),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLeavesSection('sabbatical_leaves', 'إجازات التفرغ العلمي'),
                          const SizedBox(height: 8),
                          _buildLeavesSection('unpaid_leaves', 'إجازات بدون راتب'),
                          if (viewModel.getString('sabbatical_leaves').isEmpty && viewModel.getString('unpaid_leaves').isEmpty)
                            const Text('لا توجد إجازات مسجلة'),
                        ],
                      ),
                    ),
                  ),

                  // الملفات المرفقة
                  _buildSectionHeader(context, 'الملفات المرفقة', Icons.attach_file),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildFilesSection(),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FileItemWidget extends StatelessWidget {
  final String url;
  final String title;
  final MobileFacultyProfileViewModel viewModel;

  const _FileItemWidget({required this.url, required this.title, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isDownloading = viewModel.isDownloading(url);

    return ListTile(
      dense: true,
      leading: isDownloading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download, color: DesktopColors.primary),
      title: Text(title, style: const TextStyle(color: DesktopColors.primary, decoration: TextDecoration.underline)),
      onTap: isDownloading ? null : () => viewModel.downloadAndOpenFile(context, url, title),
    );
  }
}
