import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:file_picker/file_picker.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({Key? key}) : super(key: key);

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers للحقول النصية
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final RequestViewModel _viewModel = RequestViewModel();

  List<String> _departments = [];
  String? _selectedDepartment;
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    // تعبئة بيانات المستخدم تلقائياً من الجلسة
    _nameController.text = AppSession().userName;
    _collegeController.text = AppSession().userCollege;
    _selectedDepartment = AppSession().userDepartment.isNotEmpty ? AppSession().userDepartment : null;
    _departmentController.text = _selectedDepartment ?? '';
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final colleges = await db.query('colleges');
      final departments = await db.query('departments');

      final college = colleges.firstWhere(
        (c) => c['ar_name'].toString() == AppSession().userCollege,
        orElse: () => {},
      );

      if (college.isNotEmpty) {
        final collegeId = college['id'];
        final list = departments
            .where((d) => d['college_id'] == collegeId)
            .map((d) => d['name'].toString())
            .toList();
        if (mounted) {
          setState(() {
            _departments = list;
            if (_selectedDepartment != null && !_departments.contains(_selectedDepartment)) {
              _departments.add(_selectedDepartment!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading departments on mobile: $e');
    }
  }

  // متغيرات للحقول الأخرى
  String? _selectedLeaveType;
  DateTime? _startDate;
  final DateTime _requestDate = DateTime.now();

  // خيارات نوع الإجازة المستخرجة من الاستمارة
  final List<String> _leaveTypes = [
    "إجازة لأداء الحج",
    "إجازة لأداء العمرة",
    "إجازة وضع",
    "إجازة مرضية",
    "إجازة مرافقة مريض للعلاج في الخارج",
    "إجازة اضطرارية"
  ];

  // دالة لاختيار التاريخ
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // دالة الإرسال
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تحديد تاريخ بدء الإجازة')),
        );
        return;
      }

      // إظهار مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // تجهيز البيانات الإضافية للنموذج
      final Map<String, dynamic> extraData = {
        'form_id': 'faculty_leave_request',
        'leave_type': _selectedLeaveType,
        'duration': int.parse(_durationController.text),
        'start_date': _startDate!.toIso8601String(),
        'request_date': _requestDate.toIso8601String(),
        'current_step_order': 1, // 1: رئيس القسم بالكلية، 2: نائب الشؤون الأكاديمية بالكلية، 3: العميد بالكلية، 4: النيابة العامة برئاسة الجامعة
        'sender_department': _departmentController.text.trim(),
      };

      if (_notesController.text.trim().isNotEmpty) {
        extraData['notes'] = _notesController.text.trim();
      }

      String description = 'المدة: ${_durationController.text} أيام ابتداءً من ${intl.DateFormat('yyyy/MM/dd').format(_startDate!)}';
      if (_notesController.text.trim().isNotEmpty) {
        description += '\nملاحظات: ${_notesController.text.trim()}';
      }

      // إرسال الطلب عبر الـ ViewModel
      bool success = await _viewModel.sendRequest(
        title: 'طلب إجازة: $_selectedLeaveType',
        destinationCollege: _collegeController.text, // يُرسل لكلية الموظف نفسه (إلى رئيس القسم)
        type: 'استمارة طلب إجازة',
        description: description,
        applicantName: _nameController.text,
        senderCollege: _collegeController.text,
        extraData: extraData,
        attachedFiles: _selectedFile != null ? [_selectedFile!] : null,
      );

      // إخفاء مؤشر التحميل
      if (mounted) Navigator.pop(context);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال الطلب بنجاح لرئيس القسم!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // العودة للشاشة السابقة
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
    // التأكد من دعم الاتجاه من اليمين لليسار (RTL) للغة العربية
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استمارة طلب إجازة'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. قسم البيانات الأساسية
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
                  validator: (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _collegeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'الكلية',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.account_balance),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _departments.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: _departments.contains(_selectedDepartment) ? _selectedDepartment : null,
                              decoration: const InputDecoration(
                                labelText: 'القسم الأكاديمي',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _departments.map((String dept) {
                                return DropdownMenuItem<String>(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedDepartment = newValue;
                                  _departmentController.text = newValue ?? '';
                                });
                              },
                              validator: (value) => value == null ? 'الرجاء اختيار القسم' : null,
                            )
                          : TextFormField(
                              controller: _departmentController,
                              readOnly: _departmentController.text.isNotEmpty,
                              decoration: InputDecoration(
                                labelText: 'القسم الأكاديمي',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.category),
                                filled: _departmentController.text.isNotEmpty,
                                fillColor: _departmentController.text.isNotEmpty ? Colors.grey[100] : null,
                              ),
                              validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. قسم تفاصيل الإجازة
                _buildSectionTitle('تفاصيل الإجازة'),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الإجازة المطلوبة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.beach_access),
                  ),
                  value: _selectedLeaveType,
                  items: _leaveTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLeaveType = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'الرجاء اختيار نوع الإجازة' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المدة (بالأيام)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'مطلوب';
                          if (int.tryParse(value) == null) return 'أدخل رقماً صحيحاً';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectStartDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'ابتداءً من تاريخ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _startDate == null
                                ? 'اختر التاريخ'
                                : intl.DateFormat('yyyy/MM/dd').format(_startDate!),
                            style: TextStyle(
                              color: _startDate == null ? Colors.grey[600] : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('معلومات إضافية (اختياري)'),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_alt),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                _buildAttachmentSection(),
                const SizedBox(height: 24),

                // 3. معلومات النظام
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'تاريخ تقديم الطلب: ${intl.DateFormat('yyyy/MM/dd').format(_requestDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // زر الإرسال
                ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال الطلب (لرئيس القسم)', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
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

  // أداة مساعدة لرسم عناوين الأقسام
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

  Future<void> _pickAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الملف: $e')),
      );
    }
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('المرفقات (اختياري)'),
        if (_selectedFile != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _pickAttachment,
          icon: const Icon(Icons.attach_file),
          label: Text(_selectedFile == null ? 'إرفاق مستند' : 'تغيير المستند المرفق'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _collegeController.dispose();
    _departmentController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
