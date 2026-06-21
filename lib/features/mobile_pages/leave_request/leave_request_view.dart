import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'leave_request_view_model.dart';

class LeaveRequestView extends StatefulWidget {
  const LeaveRequestView({Key? key}) : super(key: key);

  @override
  State<LeaveRequestView> createState() => _LeaveRequestViewState();
}

class _LeaveRequestViewState extends State<LeaveRequestView> {
  final _formKey = GlobalKey<FormState>();

  // دالة لاختيار التاريخ
  Future<void> _selectStartDate(BuildContext context, LeaveRequestViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: viewModel.startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != viewModel.startDate) {
      viewModel.setStartDate(picked);
    }
  }

  // دالة الإرسال
  Future<void> _submitForm(LeaveRequestViewModel viewModel) async {
    if (_formKey.currentState!.validate()) {
      if (viewModel.startDate == null) {
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

      bool success = await viewModel.submitForm();

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
              content: Text(viewModel.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LeaveRequestViewModel>(
      create: (_) => LeaveRequestViewModel(),
      child: Consumer<LeaveRequestViewModel>(
        builder: (context, viewModel, child) {
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
                        controller: viewModel.nameController,
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
                              controller: viewModel.collegeController,
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
                            child: viewModel.departments.isNotEmpty
                                ? DropdownButtonFormField<String>(
                                    value: viewModel.departments.contains(viewModel.selectedDepartment) 
                                        ? viewModel.selectedDepartment 
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'القسم الأكاديمي',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.category),
                                    ),
                                    items: viewModel.departments.map((String dept) {
                                      return DropdownMenuItem<String>(
                                        value: dept,
                                        child: Text(dept),
                                      );
                                    }).toList(),
                                    onChanged: viewModel.setSelectedDepartment,
                                    validator: (value) => value == null ? 'الرجاء اختيار القسم' : null,
                                  )
                                : TextFormField(
                                    controller: viewModel.departmentController,
                                    readOnly: viewModel.departmentController.text.isNotEmpty,
                                    decoration: InputDecoration(
                                      labelText: 'القسم الأكاديمي',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.category),
                                      filled: viewModel.departmentController.text.isNotEmpty,
                                      fillColor: viewModel.departmentController.text.isNotEmpty ? Colors.grey[100] : null,
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
                        value: viewModel.selectedLeaveType,
                        items: viewModel.leaveTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: viewModel.setSelectedLeaveType,
                        validator: (value) => value == null ? 'الرجاء اختيار نوع الإجازة' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: viewModel.durationController,
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
                              onTap: () => _selectStartDate(context, viewModel),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'ابتداءً من تاريخ',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  viewModel.startDate == null
                                      ? 'اختر التاريخ'
                                      : intl.DateFormat('yyyy/MM/dd').format(viewModel.startDate!),
                                  style: TextStyle(
                                    color: viewModel.startDate == null ? Colors.grey[600] : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. معلومات النظام
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'تاريخ تقديم الطلب: ${intl.DateFormat('yyyy/MM/dd').format(viewModel.requestDate)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // زر الإرسال
                      ElevatedButton.icon(
                        onPressed: () => _submitForm(viewModel),
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
        },
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
}
