import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:file_picker/file_picker.dart';

class GeneralRequestScreen extends StatefulWidget {
  const GeneralRequestScreen({Key? key}) : super(key: key);

  @override
  State<GeneralRequestScreen> createState() => _GeneralRequestScreenState();
}

class _GeneralRequestScreenState extends State<GeneralRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final RequestViewModel _viewModel = RequestViewModel();
  final _session = AppSession();

  List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = _session.userName;
    _collegeController.text = _session.userCollege;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _collegeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الملف: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final Map<String, dynamic> extraData = {
        'form_id': 'general_request',
        'request_date': DateTime.now().toIso8601String(),
        'current_step_order': 1, // تبدأ من رئيس القسم (الخطوة 1)
        'sender_department': _session.userDepartment.trim(),
      };

      bool success = await _viewModel.sendRequest(
        title: _titleController.text.trim(),
        destinationCollege: _collegeController.text, // موجهة لكلية مقدم الطلب (رئيس القسم كبداية)
        type: 'طلب عام',
        description: _descriptionController.text.trim(),
        applicantName: _nameController.text,
        senderCollege: _collegeController.text,
        extraData: extraData,
        attachedFiles: _selectedFiles.isNotEmpty ? _selectedFiles : null,
      );

      if (mounted) Navigator.pop(context); // Hide loading dialog

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال الطلب العام بنجاح وسيدخل مسار الموافقات!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to requests list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_viewModel.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استمارة طلب عام'),
          centerTitle: true,
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('البيانات الأساسية'),
                TextFormField(
                  controller: _nameController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'الاسم رباعياً',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _collegeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'الكلية',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('تفاصيل الطلب العام'),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الطلب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'الرجاء إدخال عنوان الطلب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل أو ملاحظات حول الطلب',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 4,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'الرجاء إدخال تفاصيل الطلب' : null,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('المرفقات (اختياري)'),
                if (_selectedFiles.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: _selectedFiles
                          .map((file) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFiles.remove(file);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_selectedFiles.isEmpty ? 'إرفاق ملفات' : 'تغيير الملفات المرفقة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال الطلب العام', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesktopColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }
}
