import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'mobile_faculty_edit_view_model.dart';

class MobileFacultyEditView extends StatefulWidget {
  final Map<String, dynamic> facultyData;

  const MobileFacultyEditView({super.key, required this.facultyData});

  @override
  State<MobileFacultyEditView> createState() => _MobileFacultyEditViewState();
}

class _MobileFacultyEditViewState extends State<MobileFacultyEditView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  late final MobileFacultyEditViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _viewModel = MobileFacultyEditViewModel(facultyData: widget.facultyData);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _viewModel.submitRequest(context);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب للنيابة بنجاح'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال الطلب أو لم يتم تغيير أي شيء'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildField(String key, String label, {bool isRequired = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _viewModel.ctrls[key],
        maxLines: maxLines,
        validator: isRequired ? (val) => (val == null || val.trim().isEmpty) ? 'مطلوب' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilesTab() {
    List<Widget> children = [];

    _viewModel.fileCategories.forEach((catKey, catLabel) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(catLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );

      // الملفات الحالية (قابلة للحذف)
      if (_viewModel.existingFiles[catKey] != null && _viewModel.existingFiles[catKey]!.isNotEmpty) {
        for (String url in _viewModel.existingFiles[catKey]!) {
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.file_present),
                title: const Text('ملف محفوظ مسبقاً', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _viewModel.markExistingFileForDeletion(catKey, url),
                ),
              ),
            ),
          );
        }
      }

      // الملفات الجديدة المضافة
      if (_viewModel.newFilesMapping[catKey] != null && _viewModel.newFilesMapping[catKey]!.isNotEmpty) {
        for (int mappedIndex in _viewModel.newFilesMapping[catKey]!) {
          PlatformFile pFile = _viewModel.newAttachedFiles[mappedIndex];
          children.add(
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              color: Colors.green.shade50,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.upload_file, color: Colors.green),
                title: Text(pFile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _viewModel.removeNewFile(catKey, mappedIndex),
                ),
              ),
            ),
          );
        }
      }

      // زر الإضافة لهذه الفئة
      children.add(
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _viewModel.pickNewFile(catKey),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('إرفاق ملف جديد'),
          ),
        ),
      );
      children.add(const Divider());
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MobileFacultyEditViewModel>.value(
      value: _viewModel,
      child: Consumer<MobileFacultyEditViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('تعديل البيانات والمرفقات'),
              centerTitle: true,
              backgroundColor: DesktopColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: viewModel.isSubmitting ? null : _submitRequest,
                  tooltip: 'إرسال التعديلات',
                )
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'أساسي'),
                  Tab(text: 'بكالوريوس'),
                  Tab(text: 'ماجستير'),
                  Tab(text: 'دكتوراه'),
                  Tab(text: 'الترقيات'),
                  Tab(text: 'المرفقات'),
                ],
              ),
            ),
            body: viewModel.isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. أساسي
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildField('name', 'الاسم الكامل', isRequired: true),
                            _buildField('email', 'البريد الإلكتروني', isRequired: true),
                            _buildField('department', 'القسم العلمي', isRequired: true),
                            _buildField('status', 'حالة العضو (نشط/متفرغ..)'),
                            _buildField('job_number', 'الرقم الوظيفي'),
                            _buildField('file_number', 'رقم الملف'),
                            _buildField('id_card_number', 'رقم الهوية'),
                            Row(
                              children: [
                                Expanded(child: _buildField('birth_place', 'مكان الميلاد')),
                                const SizedBox(width: 8),
                                Expanded(child: _buildField('birth_date', 'تاريخ الميلاد')),
                              ],
                            ),
                            _buildField('general_specialization', 'التخصص العام'),
                            _buildField('exact_specialization', 'التخصص الدقيق'),
                            const Divider(),
                            _buildField('first_appointment_date', 'تاريخ أول تعيين'),
                            _buildField('university_appointment_date', 'تاريخ التعيين بالجامعة'),
                            const Divider(),
                            _buildField('notes', 'ملاحظات للنيابة حول التعديل', maxLines: 3),
                          ],
                        ),
                        // 2. بكالوريوس
                        ListView(padding: const EdgeInsets.all(16), children: [
                          _buildField('bsc_degree', 'الدرجة'), _buildField('bsc_specialization', 'التخصص'),
                          _buildField('bsc_university', 'الجامعة'), _buildField('bsc_country', 'الدولة'),
                          _buildField('bsc_date', 'التاريخ'), _buildField('bsc_academic_title', 'اللقب الأكاديمي'),
                          _buildField('bsc_title_transfer_date', 'تاريخ نقل اللقب'),
                        ]),
                        // 3. ماجستير
                        ListView(padding: const EdgeInsets.all(16), children: [
                          _buildField('msc_degree', 'الدرجة'), _buildField('msc_exact_specialization', 'التخصص الدقيق'),
                          _buildField('msc_university', 'الجامعة'), _buildField('msc_country', 'الدولة'),
                          _buildField('msc_date', 'التاريخ'), _buildField('msc_decision_number', 'رقم القرار'),
                          _buildField('msc_academic_title', 'اللقب الأكاديمي'), _buildField('msc_title_transfer_date', 'تاريخ نقل اللقب'),
                        ]),
                        // 4. دكتوراه
                        ListView(padding: const EdgeInsets.all(16), children: [
                          _buildField('current_degree', 'الدرجة الحالية'), _buildField('current_university', 'الجامعة'),
                          _buildField('current_country', 'الدولة'), _buildField('current_degree_date', 'التاريخ'),
                        ]),
                        // 5. الترقيات
                        ListView(padding: const EdgeInsets.all(16), children: [
                          _buildField('assistant_prof_date', 'تاريخ أستاذ مساعد'), _buildField('assistant_prof_decision', 'قرار أستاذ مساعد'), const Divider(),
                          _buildField('assoc_prof_date', 'تاريخ أستاذ مشارك'), _buildField('assoc_prof_decision', 'قرار أستاذ مشارك'), const Divider(),
                          _buildField('current_academic_title', 'اللقب الأكاديمي الحالي'), _buildField('title_transfer_date', 'تاريخ نقل اللقب'),
                        ]),
                        // 6. المرفقات
                        _buildFilesTab(),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
