import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'request_model.dart';
import 'request_view_model.dart';

class RequestsView extends StatefulWidget {
  const RequestsView({super.key});

  @override
  State<RequestsView> createState() => _RequestsViewState();
}

class _RequestsViewState extends State<RequestsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RequestViewModel _viewModel = RequestViewModel();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _viewModel.loadColleges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentStepOwner(RequestModel req) {
    if (req.status == 'مقبول') return 'تم الاعتماد النهائي';
    if (req.status == 'مرفوض') {
      final rejectorRole = req.extraData?['rejected_by_role'] ?? 'الجهة المستقبلة';
      return 'تم الرفض من قبل $rejectorRole';
    }
    if (req.status == 'تم الرد') return 'تم الرد من قبل عميد الكلية';
    
    final int step = req.extraData?['current_step_order'] != null
        ? (req.extraData!['current_step_order'] is int
            ? req.extraData!['current_step_order'] as int
            : int.tryParse(req.extraData!['current_step_order'].toString()) ?? 1)
        : 1;

    switch (step) {
      case 1:
        return 'رئيس القسم العلمي بالكلية';
      case 2:
        return 'نائب العميد للشؤون الأكاديمية بالكلية';
      case 3:
        return 'عميد الكلية';
      case 4:
        return 'نيابة الشؤون الأكاديمية بالجامعة';
      default:
        return 'قيد المراجعة';
    }
  }

  Future<void> _openSpecificFile(RequestModel request, int index) async {
    List<String> urls = [];
    List<String> paths = [];

    if (request.fileUrl != null) {
      try {
        final str = request.fileUrl!.trim();
        if (str.startsWith('{')) {
          final decoded = jsonDecode(str) as Map<String, dynamic>;
          decoded.values.forEach((v) => urls.addAll(List<String>.from(v)));
        } else if (str.startsWith('[')) {
          urls = List<String>.from(jsonDecode(str));
        } else {
          urls = [str];
        }
      } catch (_) {}
    }

    if (request.localFilePath != null) {
      try {
        final str = request.localFilePath!.trim();
        if (str.startsWith('{')) {
          final decoded = jsonDecode(str) as Map<String, dynamic>;
          decoded.values.forEach((v) => paths.addAll(List<String>.from(v)));
        } else if (str.startsWith('[')) {
          paths = List<String>.from(jsonDecode(str));
        } else {
          paths = [str];
        }
      } catch (_) {}
    }

    if (index >= urls.length) return;

    String? path = index < paths.length ? paths[index] : null;
    String url = urls[index];

    Uri uri;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      uri = Uri.file(path);
    } else {
      // إذا لم يكن موجوداً محلياً، نقوم بتحميله أولاً
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'جاري تحميل الملف للمرة الأولى للوصول إليه مستقبلاً بدون إنترنت...')),
      );
      List<String>? downloadedPaths = await _viewModel.downloadFile(request);
      if (downloadedPaths != null && index < downloadedPaths.length) {
        uri = Uri.file(downloadedPaths[index]);
      } else if (url.isNotEmpty) {
        uri = Uri.parse(url);
      } else {
        return;
      }
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الملف')),
        );
      }
    }
  }

  Future<void> _exportLocalLeaveRequest(RequestModel req) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final path = await _viewModel.generateLeaveRequestLocally(req);
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (path == 'canceled') {
      // User canceled the save dialog
      return;
    }
    
    if (path == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تصدير الاستمارة')),
      );
      return;
    }
    
    if (path != null && path != 'canceled' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تصدير الاستمارة بنجاح إلى:\n$path')),
      );
    }
  }

  void _showRespondDialog(RequestModel request) {
    TextEditingController reasonController = TextEditingController();
    
    // إعداد قائمة الحقول المقبولة مبدئياً
    List<String> approvedFields = [];
    final ignoredKeys = ['deleted_files', 'new_files_mapping', 'faculty_doc_id'];
    if (request.type == 'تعديل معلومات' && request.extraData != null) {
      request.extraData!.keys.forEach((key) {
        if (!ignoredKeys.contains(key)) {
          approvedFields.add(key);
        }
      });
    }

    final keyTranslations = {
      'name': 'الاسم', 'email': 'البريد الإلكتروني', 'status': 'الحالة', 'file_number': 'رقم الملف',
      'id_card_number': 'رقم الهوية', 'job_number': 'الرقم الوظيفي', 'birth_place': 'مكان الميلاد',
      'birth_date': 'تاريخ الميلاد', 'department': 'القسم', 'general_specialization': 'التخصص العام',
      'exact_specialization': 'التخصص الدقيق', 'first_appointment_date': 'تاريخ أول تعيين',
      'university_appointment_date': 'تاريخ التعيين بالجامعة', 'bsc_degree': 'درجة البكالوريوس',
      'bsc_date': 'تاريخ البكالوريوس', 'bsc_university': 'جامعة البكالوريوس', 'bsc_country': 'دولة البكالوريوس',
      'bsc_academic_title': 'لقب البكالوريوس', 'bsc_title_transfer_date': 'تاريخ النقل (بكالوريوس)',
      'bsc_specialization': 'تخصص البكالوريوس', 'msc_degree': 'درجة الماجستير', 'msc_date': 'تاريخ الماجستير',
      'msc_university': 'جامعة الماجستير', 'msc_country': 'دولة الماجستير', 'msc_academic_title': 'لقب الماجستير',
      'msc_title_transfer_date': 'تاريخ النقل (ماجستير)', 'msc_decision_number': 'رقم القرار (ماجستير)',
      'msc_exact_specialization': 'التخصص الدقيق (ماجستير)', 'current_degree': 'الدرجة الحالية',
      'current_degree_date': 'تاريخ الدرجة الحالية', 'current_university': 'جامعة الدرجة الحالية',
      'current_country': 'دولة الدرجة الحالية', 'assistant_prof_date': 'تاريخ أستاذ مساعد',
      'assistant_prof_decision': 'قرار أستاذ مساعد', 'assoc_prof_date': 'تاريخ أستاذ مشارك',
      'assoc_prof_decision': 'قرار أستاذ مشارك', 'current_academic_title': 'اللقب الأكاديمي الحالي',
      'title_transfer_date': 'تاريخ نقل اللقب',
    };

    showDialog(
      context: context,
      builder: (context) {
        List<PlatformFile> replyFiles = [];
        return StatefulBuilder(
          builder: (context, setState) {
            final isProsecutionType = request.type == 'طلب من النيابة العامة';
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('الرد على: ${request.title}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                      'مقدم الطلب:',
                      request.applicantName.isNotEmpty
                          ? request.applicantName
                          : 'غير محدد'),
                  const SizedBox(height: 8),
                  _buildInfoRow('الكلية:', request.senderCollege),
                  const SizedBox(height: 8),
                  _buildInfoRow('نوع الطلب:', request.type),
                  const SizedBox(height: 8),
                  const Text('تفاصيل الطلب:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Text(request.description.isNotEmpty
                        ? request.description
                        : 'لا توجد تفاصيل إضافية'),
                  ),
                  if (request.type == 'تعديل معلومات' && request.extraData != null) ...[
                    const SizedBox(height: 16),
                    const Text('اختر الحقول التي توافق على تعديلها:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: request.extraData!.entries.where((e) => !ignoredKeys.contains(e.key)).map((entry) {
                          final fieldName = keyTranslations[entry.key] ?? entry.key;
                          final newValue = entry.value;
                          return CheckboxListTile(
                            title: Text('تعديل $fieldName إلى: $newValue'),
                            value: approvedFields.contains(entry.key),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  approvedFields.add(entry.key);
                                } else {
                                  approvedFields.remove(entry.key);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (request.fileUrl != null &&
                      request.fileUrl!.isNotEmpty) ...[
                    const Text('الملفات المرفقة:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      List<String> urls = [];
                      if (request.fileUrl!.startsWith('[')) {
                        try {
                          urls =
                              List<String>.from(jsonDecode(request.fileUrl!));
                        } catch (e) {
                          urls = [request.fileUrl!];
                        }
                      } else {
                        urls = [request.fileUrl!];
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: urls.asMap().entries.map((entry) {
                          int idx = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: OutlinedButton.icon(
                              onPressed: () => _openSpecificFile(request, idx),
                              icon: const Icon(Icons.attach_file),
                              label: Text('فتح الملف المرفق (${idx + 1})'),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoRow('وقت الاستلام:', _formatDate(request.dateSent)),
                  const SizedBox(height: 16),
                  Text(isProsecutionType ? 'نص الرد:' : 'سبب الرفض (مطلوب في حالة الرفض فقط):',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب الرفض هنا...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            if (isProsecutionType)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('إرسال الرد'),
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء كتابة نص الرد أولاً')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  bool success = await _viewModel.respondToRequest(
                    request.id,
                    'تم الرد',
                    rejectionReason: reasonController.text.trim(),
                    attachedFiles: replyFiles,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_viewModel.errorMessage)),
                    );
                  }
                },
              )
            else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('رفض الطلب'),
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء إدخال سبب الرفض')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  bool success = await _viewModel.respondToRequest(
                    request.id,
                    'مرفوض',
                    rejectionReason: reasonController.text,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_viewModel.errorMessage)),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('قبول الطلب'),
                onPressed: () async {
                  if (request.type == 'تعديل معلومات' && approvedFields.isEmpty && request.extraData != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء اختيار حقل واحد على الأقل للموافقة، أو اضغط رفض الطلب')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // تجهيز سبب الرفض الجزئي للحقول المرفوضة
                  String finalReason = reasonController.text.trim();
                  if (request.type == 'تعديل معلومات' && request.extraData != null) {
                    List<String> rejected = [];
                    request.extraData!.keys.forEach((key) {
                      if (!ignoredKeys.contains(key) && !approvedFields.contains(key)) {
                        rejected.add(keyTranslations[key] ?? key);
                      }
                    });
                    if (rejected.isNotEmpty) {
                      String partialReason = 'تم رفض الحقول التالية: ${rejected.join("، ")}';
                      if (finalReason.isNotEmpty) {
                        finalReason = '$partialReason\nملاحظة: $finalReason';
                      } else {
                        finalReason = partialReason;
                      }
                    }
                  }

                  // إضافة الحقول المقبولة وتحديد الحالة النهائية (إذا كان التعديل لمعلومات)
                  List<String>? approved;
                  String finalStatus = 'مقبول';
                  if (request.type == 'تعديل معلومات' && request.extraData != null) {
                    approved = approvedFields;
                    int updatableCount = request.extraData!.keys.where((k) => !ignoredKeys.contains(k)).length;
                    if (approved.length < updatableCount) {
                      finalStatus = 'مقبول جزئياً';
                    }
                  }

                  bool success = await _viewModel.respondToRequest(
                    request.id,
                    finalStatus,
                    rejectionReason: finalReason.isNotEmpty ? finalReason : null,
                    approvedFields: approved,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_viewModel.errorMessage)),
                    );
                  }
                },
              ),
            ],
          ],
        );
        });
      },
    );
  }

  void _showNewRequestDialog() {
    final isProsecution = AppSession().isAdminOrDeanship;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    
    // For normal user:
    String selectedDestination = 'نيابة الشؤون الأكاديمية';
    String selectedType = 'طلب اجازة مرضية';
    
    // For prosecution:
    String? selectedCollege;
    
    List<PlatformFile> selectedFiles = [];

    final List<String> requestTypes = [
      'طلب اجازة مرضية',
      'طلب اجازة من غير راتب',
      'طلب ترقية',
      'طلب تفرغ',
      'اخرى'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (statefulContext, setDialogState) {
          final listColleges = _viewModel.colleges.isNotEmpty 
              ? _viewModel.colleges 
              : [
                  'كلية الهندسة',
                  'كلية الحاسبات',
                  'كلية العلوم',
                  'كلية الطب',
                  'كلية طب الأسنان',
                  'كلية الصيدلة',
                  'كلية العلوم الإدارية',
                  'كلية الآداب',
                  'كلية التربية',
                ];
          if (isProsecution && selectedCollege == null && listColleges.isNotEmpty) {
            selectedCollege = listColleges.first;
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(isProsecution ? 'إنشاء طلب جديد (النيابة العامة)' : 'إنشاء طلب جديد'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: isProsecution ? 'الموضوع / العنوان' : 'عنوان الطلب',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isProsecution) ...[
                      DropdownButtonFormField<String>(
                        value: selectedCollege,
                        decoration: InputDecoration(
                          labelText: 'الكلية المرسل إليها',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: listColleges
                            .map(
                                (e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setDialogState(() => selectedCollege = v);
                        },
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: selectedDestination,
                        decoration: InputDecoration(
                          labelText: 'الجهة الموجه إليها',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          'جميع الكليات',
                          'كلية الهندسة',
                          'كلية الحاسبات',
                          'كلية العلوم',
                          'نيابة الشؤون الأكاديمية'
                        ]
                            .map(
                                (e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null)
                            setDialogState(() => selectedDestination = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'نوع الطلب',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: requestTypes
                            .map(
                                (e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedType = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: isProsecution ? 'نص الرسالة / الطلب' : 'تفاصيل أو ملاحظات حول الطلب',
                        hintText: 'اكتب تفاصيل إضافية هنا...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedFiles.isNotEmpty
                                      ? 'تم اختيار (${selectedFiles.length}) ملفات'
                                      : 'لم يتم اختيار ملفات بعد',
                                  style: TextStyle(
                                    color: selectedFiles.isNotEmpty
                                        ? Colors.blue[800]
                                        : Colors.grey,
                                    fontWeight: selectedFiles.isNotEmpty
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  FilePickerResult? result =
                                      await FilePicker.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'png',
                                      'doc',
                                      'docx'
                                    ],
                                    allowMultiple: true,
                                  );
                                  if (result != null) {
                                    setDialogState(
                                        () => selectedFiles = result.files);
                                  }
                                },
                                icon: const Icon(Icons.upload_file),
                                label: const Text('اختيار ملفات'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesktopColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (selectedFiles.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                children: selectedFiles
                                    .map((f) => Row(
                                          children: [
                                            const Icon(Icons.description,
                                                size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Expanded(
                                                child: Text(f.name,
                                                    style: const TextStyle(
                                                        fontSize: 11))),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  size: 14, color: Colors.red),
                                              onPressed: () => setDialogState(
                                                  () =>
                                                      selectedFiles.remove(f)),
                                            )
                                          ],
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  if (isProsecution && selectedCollege == null) return;
                  Navigator.pop(statefulContext);

                  bool success = await _viewModel.sendRequest(
                    title: titleController.text.trim(),
                    destinationCollege: isProsecution ? selectedCollege! : selectedDestination,
                    type: isProsecution ? 'طلب من النيابة العامة' : selectedType,
                    description: descriptionController.text.trim(),
                    attachedFiles: selectedFiles,
                  );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isProsecution ? 'تم إرسال الطلب بنجاح إلى عميد الكلية' : 'تم إرسال الطلب بنجاح')),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_viewModel.errorMessage)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesktopColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إرسال'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: const SharedDesktopAppBar(),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(DesktopSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'إدارة الطلبات',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: DesktopColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () => _viewModel.refreshRequests(),
                              icon: const Icon(Icons.refresh,
                                  color: DesktopColors.primary),
                              tooltip: 'تحديث البيانات',
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showNewRequestDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('طلب جديد'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesktopColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: DesktopColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: DesktopColors.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.inbox), text: 'الطلبات الواردة'),
                          Tab(icon: Icon(Icons.send), text: 'الطلبات الصادرة'),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesktopSpacing.md),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildReceivedRequestsTab(),
                          _buildSentRequestsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_viewModel.isSending || _viewModel.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                            _viewModel.isSending
                                ? 'جاري المعالجة ورفع الملف...'
                                : 'جاري تحديث الصفحة...',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReceivedRequestsTab() {
    if (_viewModel.receivedRequests.isEmpty) {
      return const Center(child: Text('لا توجد طلبات واردة'));
    }

    return ListView.builder(
      itemCount: _viewModel.receivedRequests.length,
      itemBuilder: (context, index) {
        final req = _viewModel.receivedRequests[index];
        Color statusColor = Colors.orange;
        if (req.status == 'مقبول') statusColor = Colors.green;
        if (req.status == 'مقبول جزئياً') statusColor = Colors.teal;
        if (req.status == 'مرفوض') statusColor = Colors.red;
        if (req.status == 'تم الرد') statusColor = Colors.blue;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      req.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        req.status,
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child:
                            _buildInfoRow('الجهة المرسلة:', req.senderCollege)),
                    Expanded(
                        child: _buildInfoRow(
                            'مقدم الطلب:',
                            req.applicantName.isNotEmpty
                                ? req.applicantName
                                : 'غير محدد')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('النوع:', req.type)),
                  ],
                ),
                if (req.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('التفاصيل: ${req.description}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('الاستلام: ${_formatDate(req.dateSent)}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: req.dateReplied != null
                          ? Row(
                              children: [
                                const Icon(Icons.done_all,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('الرد: ${_formatDate(req.dateReplied!)}'),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
                if ((req.status == 'مرفوض' || req.status == 'مقبول جزئياً') && req.rejectionReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سبب الرفض: ${req.rejectionReason}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (req.status == 'تم الرد' && req.rejectionReason != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الرد: ${req.rejectionReason}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (req.extraData != null && req.extraData!['reply_attachments'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Builder(builder: (context) {
                        List<String> urls = [];
                        try {
                          final val = req.extraData!['reply_attachments'];
                          if (val is String) {
                            urls = List<String>.from(jsonDecode(val));
                          } else if (val is List) {
                            urls = List<String>.from(val);
                          }
                        } catch (_) {}
                        return Wrap(
                          spacing: 8,
                          children: urls.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String url = entry.value;
                            return OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(url);
                                try {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.attach_file, size: 14),
                              label: Text('ملف الرد (${idx + 1})'),
                            );
                          }).toList(),
                        );
                      }),
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (req.fileUrl != null && req.fileUrl!.isNotEmpty)
                      Builder(builder: (context) {
                        List<String> urls = [];
                        if (req.fileUrl!.startsWith('[')) {
                          try {
                            urls = List<String>.from(jsonDecode(req.fileUrl!));
                          } catch (e) {
                            urls = [req.fileUrl!];
                          }
                        } else {
                          urls = [req.fileUrl!];
                        }

                        return Row(
                          children: urls.asMap().entries.map((entry) {
                            int idx = entry.key;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: OutlinedButton.icon(
                                onPressed: () => _openSpecificFile(req, idx),
                                icon: const Icon(Icons.visibility),
                                label: Text('فتح الملف (${idx + 1})'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue[800],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    const SizedBox(width: 12),
                    if ((req.type == 'استمارة طلب إجازة' || req.type.contains('إجازة') || req.type.contains('اجازة')) && req.status == 'مقبول')
                      ElevatedButton.icon(
                        onPressed: () => _exportLocalLeaveRequest(req),
                        icon: const Icon(Icons.file_download, color: Colors.white, size: 16),
                        label: const Text('تصدير الاستمارة', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (req.status == 'قيد الانتظار')
                      ElevatedButton.icon(
                        onPressed: () => _showRespondDialog(req),
                        icon: const Icon(Icons.reply),
                        label: const Text('اتخاذ إجراء'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesktopColors.primary,
                          foregroundColor: Colors.white,
                        ),
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

  Widget _buildSentRequestsTab() {
    if (_viewModel.sentRequests.isEmpty) {
      return const Center(child: Text('لا توجد طلبات صادرة'));
    }

    return ListView.builder(
      itemCount: _viewModel.sentRequests.length,
      itemBuilder: (context, index) {
        final req = _viewModel.sentRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(req.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'الجهة: ${req.destinationCollege} | الحالة: ${req.status}'),
            leading: CircleAvatar(
              backgroundColor: req.status == 'مقبول'
                  ? Colors.green
                  : (req.status == 'مرفوض'
                      ? Colors.red
                      : (req.status == 'تم الرد' ? Colors.blue : Colors.orange)),
              child: const Icon(Icons.outbox, color: Colors.white, size: 20),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('النوع:', req.type),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        'التفاصيل:',
                        req.description.isNotEmpty
                            ? req.description
                            : 'لا توجد'),
                    const SizedBox(height: 8),
                    _buildInfoRow('تاريخ الإرسال:', _formatDate(req.dateSent)),
                    if (req.type != 'طلب من النيابة العامة') ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('عند من الطلب الآن:', _getCurrentStepOwner(req)),
                    ],
                    if (req.dateReplied != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                          'تاريخ الرد:', _formatDate(req.dateReplied!)),
                    ],
                    if (req.status == 'مرفوض' &&
                        req.rejectionReason != null) ...[
                      const SizedBox(height: 8),
                      Text('سبب الرفض: ${req.rejectionReason}',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    if (req.status == 'تم الرد' && req.rejectionReason != null) ...[
                      const SizedBox(height: 8),
                      Text('الرد: ${req.rejectionReason}',
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold)),
                      if (req.extraData != null && req.extraData!['reply_attachments'] != null) ...[
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          List<String> urls = [];
                          try {
                            final val = req.extraData!['reply_attachments'];
                            if (val is String) {
                              urls = List<String>.from(jsonDecode(val));
                            } else if (val is List) {
                              urls = List<String>.from(val);
                            }
                          } catch (_) {}
                          return Wrap(
                            spacing: 8,
                            children: urls.asMap().entries.map((entry) {
                              int idx = entry.key;
                              String url = entry.value;
                              return OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(url);
                                  try {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.attach_file, size: 14, color: Colors.blue),
                                label: Text('ملف الرد (${idx + 1})', style: const TextStyle(color: Colors.blue)),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ],
                    if (req.fileUrl != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSpecificFile(req, 0),
                          icon: const Icon(Icons.file_download),
                          label: const Text('فتح/تحميل الملف المرسل'),
                        ),
                      ),
                    ],
                    if ((req.type == 'استمارة طلب إجازة' || req.type.contains('إجازة') || req.type.contains('اجازة')) && req.status == 'مقبول') ...[
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _exportLocalLeaveRequest(req),
                          icon: const Icon(Icons.file_download, color: Colors.white, size: 16),
                          label: const Text('تصدير الاستمارة الرسمية', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
