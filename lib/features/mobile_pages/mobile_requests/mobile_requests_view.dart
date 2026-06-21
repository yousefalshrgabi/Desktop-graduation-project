import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'mobile_request_model.dart';
import 'mobile_requests_view_model.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:academic_affairs_management/features/mobile_pages/leave_request/leave_request_view.dart';

class MobileRequestsView extends StatefulWidget {
  const MobileRequestsView({super.key});

  @override
  State<MobileRequestsView> createState() => _MobileRequestsViewState();
}

class _MobileRequestsViewState extends State<MobileRequestsView> {
  final MobileRequestsViewModel _viewModel = MobileRequestsViewModel();
  final _session = AppSession();

  @override
  void initState() {
    super.initState();
    // استخدام بيانات الجلسة الحقيقية للفلترة والتعريف
    _viewModel.setUserData(
      name: _session.userName,
      college: _session.userCollege,
      role: _session.userRole,
      userId: _session.userId,
      department: _session.userDepartment,
    );
    _viewModel.loadColleges(); // 👈 جلب الكليات
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStepLabel(dynamic stepVal) {
    int step = stepVal is int ? stepVal : int.tryParse(stepVal.toString()) ?? 1;
    switch (step) {
      case 1:
        return 'رئيس القسم بالكلية';
      case 2:
        return 'نائب الشؤون الأكاديمية بالكلية';
      case 3:
        return 'عميد الكلية';
      case 4:
        return 'النيابة العامة برئاسة الجامعة';
      default:
        return 'جهة المراجعة';
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد ملف مرفق')),
      );
      return;
    }

    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('[') && cleanUrl.endsWith(']')) {
      try {
        final List<dynamic> decoded = jsonDecode(cleanUrl);
        if (decoded.isNotEmpty) {
          cleanUrl = decoded.first.toString();
        }
      } catch (e) {
        cleanUrl = cleanUrl
            .substring(1, cleanUrl.length - 1)
            .replaceAll('"', '')
            .replaceAll("'", "")
            .trim();
      }
    }

    if (cleanUrl.startsWith('"') && cleanUrl.endsWith('"')) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }
    if (cleanUrl.startsWith("'") && cleanUrl.endsWith("'")) {
      cleanUrl = cleanUrl.substring(1, cleanUrl.length - 1);
    }

    final Uri uri = Uri.parse(cleanUrl);
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

  Future<void> _viewLocalLeaveRequest(RequestModel req) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري توليد الاستمارة الرسمية محلياً...'),
              ],
            ),
          ),
        ),
      ),
    );

    final path = await _viewModel.generateLeaveRequestLocally(req);
    if (mounted) {
      Navigator.pop(context);
    }

    if (path != null) {
      final Uri uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الملف المولد محلياً')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل توليد الاستمارة محلياً')),
        );
      }
    }
  }

  void _showRequestTypesDialog() {
    if (_session.isAdminOrDeanship) {
      _showProsecutionRequestBottomSheet();
      return;
    }
    String selectedForm = 'leave_request';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('اختر نوع الطلب',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'الرجاء تحديد نوع الطلب من القائمة المنسدلة للبدء بتعبئة الاستمارة الخاصة به.',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedForm,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'leave_request', child: Text('طلب إجازة')),
                      DropdownMenuItem(
                          value: 'general_request', child: Text('طلب عام')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedForm = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedForm == 'leave_request') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaveRequestView(),
                        ),
                      );
                    } else {
                      _showNewRequestBottomSheet();
                    }
                  },
                  child: const Text('متابعة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewRequestBottomSheet() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedDestination = 'نيابة الشؤون الأكاديمية';
    String selectedType = 'طلب اجازة مرضية';
    List<PlatformFile> selectedFiles = [];

    final List<String> requestTypes = [
      'طلب اجازة مرضية',
      'طلب اجازة من غير راتب',
      'طلب ترقية',
      'طلب تفرغ',
      'اخرى'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (statefulContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إنشاء طلب جديد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'عنوان الطلب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDestination,
                    decoration: InputDecoration(
                      labelText: 'الجهة الموجه إليها',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      'نيابة الشؤون الأكاديمية',
                      'جميع الكليات',
                      'كلية الحاسبات'
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => selectedDestination = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'نوع الطلب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: requestTypes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'تفاصيل أو ملاحظات حول الطلب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        if (selectedFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              children: selectedFiles
                                  .map((f) => Row(
                                        children: [
                                          const Icon(Icons.file_present,
                                              color: DesktopColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(f.name,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                          IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            onPressed: () => setSheetState(
                                                () => selectedFiles.remove(f)),
                                          )
                                        ],
                                      ))
                                  .toList(),
                            ),
                          ),
                        OutlinedButton.icon(
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
                              setSheetState(() => selectedFiles = result.files);
                            }
                          },
                          icon: const Icon(Icons.attach_file),
                          label: Text(selectedFiles.isEmpty
                              ? 'إرفاق ملفات'
                              : 'تغيير الملفات'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(45),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;
                      Navigator.pop(statefulContext);

                      bool success = await _viewModel.sendRequest(
                        title: titleController.text.trim(),
                        destinationCollege: selectedDestination,
                        type: selectedType,
                        description: descriptionController.text.trim(),
                        attachedFiles: selectedFiles,
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم الإرسال بنجاح')),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('إرسال الطلب',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showRespondBottomSheet(RequestModel request) {
    TextEditingController reasonController = TextEditingController();
    List<PlatformFile> replyFiles = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: request.type == 'طلب من النيابة العامة'
                  ? [
                      Text(
                        'الرد على: ${request.title}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('الجهة المرسلة:', request.senderCollege),
                      const SizedBox(height: 12),
                      const Text('نص الرسالة / الطلب:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Text(request.description,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                      if (request.fileUrl != null && request.fileUrl!.isNotEmpty) ...[
                        const Text('المرفقات:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          List<String> urls = [];
                          if (request.fileUrl!.startsWith('[')) {
                            try {
                              urls = List<String>.from(jsonDecode(request.fileUrl!));
                            } catch (_) {
                              urls = [request.fileUrl!];
                            }
                          } else {
                            urls = [request.fileUrl!];
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: urls.asMap().entries.map((entry) {
                              int idx = entry.key;
                              String url = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: OutlinedButton.icon(
                                  onPressed: () => _openFile(url),
                                  icon: const Icon(Icons.visibility),
                                  label: Text('عرض الملف المرفق (${idx + 1})'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'نص الرد',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text('إرفاق ملفات مع الرد (اختياري):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    replyFiles.isNotEmpty
                                        ? 'تم إرفاق ${replyFiles.length} ملف/ملفات'
                                        : 'لم يتم إرفاق ملفات',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: replyFiles.isNotEmpty
                                          ? Colors.blue[800]
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.attach_file, size: 14),
                                  label: const Text('إرفاق ملفات', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () async {
                                    final result = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
                                      allowMultiple: true,
                                    );
                                    if (result != null) {
                                      setState(() => replyFiles = result.files);
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (replyFiles.isNotEmpty)
                              ...replyFiles.map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.description,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(f.name,
                                              style: const TextStyle(fontSize: 12))),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 14, color: Colors.red),
                                        onPressed: () => setState(() =>
                                            replyFiles.remove(f)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال الرد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () async {
                          if (reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('الرجاء كتابة نص الرد أولاً')),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          await _viewModel.respondToRequest(
                            request.id,
                            'تم الرد',
                            rejectionReason: reasonController.text.trim(),
                            attachedFiles: replyFiles,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ]
                  : [
                      Text(
                        'الرد على: ${request.title}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('مقدم الطلب:', request.applicantName),
                      const SizedBox(height: 8),
                      _buildInfoRow('نوع الطلب:', request.type),
                      const SizedBox(height: 8),
                      const Text('تفاصيل الطلب:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
                      Text(request.description.isNotEmpty
                          ? request.description
                          : 'لا توجد تفاصيل'),
                      const SizedBox(height: 16),
                      if (request.fileUrl != null) ...[
                        OutlinedButton.icon(
                          onPressed: () => _openFile(request.fileUrl),
                          icon: const Icon(Icons.visibility),
                          label: const Text('فتح الملف المرفق'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'سبب الرفض (مطلوب للرفض فقط)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text('رفض'),
                              onPressed: () async {
                                if (reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('الرجاء إدخال سبب الرفض')),
                                  );
                                  return;
                                }
                                Navigator.pop(context);
                                await _viewModel.respondToRequest(
                                  request.id,
                                  'مرفوض',
                                  rejectionReason: reasonController.text,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('قبول'),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _viewModel.respondToRequest(
                                    request.id, 'مقبول');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProsecutionRequestBottomSheet() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    List<PlatformFile> selectedFiles = [];
    String? selectedCollege;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (statefulContext, setSheetState) {
          final listColleges = _viewModel.colleges;
          if (selectedCollege == null && listColleges.isNotEmpty) {
            selectedCollege = listColleges.first;
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إنشاء طلب جديد (النيابة العامة)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text('الكلية المرسل إليها:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCollege,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: listColleges
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => selectedCollege = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'الموضوع / العنوان',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'نص الرسالة / الطلب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        if (selectedFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              children: selectedFiles
                                  .map((f) => Row(
                                        children: [
                                          const Icon(Icons.file_present,
                                              color: DesktopColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(f.name,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                          IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            onPressed: () => setSheetState(
                                                () => selectedFiles.remove(f)),
                                          )
                                        ],
                                      ))
                                  .toList(),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            FilePickerResult? result =
                                await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
                              allowMultiple: true,
                            );
                            if (result != null) {
                              setSheetState(() => selectedFiles = result.files);
                            }
                          },
                          icon: const Icon(Icons.attach_file),
                          label: Text(selectedFiles.isEmpty
                              ? 'إرفاق ملفات'
                              : 'إضافة المزيد من الملفات'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(45),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedCollege == null) return;
                      if (titleController.text.trim().isEmpty) return;
                      if (descriptionController.text.trim().isEmpty) return;
                      Navigator.pop(statefulContext);

                      bool success = await _viewModel.sendRequest(
                        title: titleController.text.trim(),
                        destinationCollege: selectedCollege!,
                        type: 'طلب من النيابة العامة',
                        description: descriptionController.text.trim(),
                        attachedFiles: selectedFiles,
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم الإرسال بنجاح إلى عميد الكلية')),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('إرسال الطلب',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلبات'),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => _viewModel.refreshRequests(),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.inbox), text: 'الواردة'),
              Tab(icon: Icon(Icons.send), text: 'الصادرة'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, child) {
            return Stack(
              children: [
                TabBarView(
                  children: [
                    _buildRequestsList(_viewModel.receivedRequests,
                        isReceived: true),
                    _buildRequestsList(_viewModel.sentRequests,
                        isReceived: false),
                  ],
                ),
                if (_viewModel.isSending || _viewModel.isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                              _viewModel.isSending
                                  ? 'جاري الإرسال ورفع الملف...'
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
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'mobile_requests_fab',
          onPressed: _showRequestTypesDialog,
          backgroundColor: Colors.blue[800],
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('طلب جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<RequestModel> requests,
      {required bool isReceived}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('لا توجد طلبات ${isReceived ? 'واردة' : 'صادرة'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        Color statusColor = Colors.orange;
        if (req.status == 'مقبول') statusColor = Colors.green;
        if (req.status == 'مرفوض') statusColor = Colors.red;
        if (req.status == 'تم الرد') statusColor = Colors.blue;

        final bool isLeaveRequest = req.type == 'استمارة طلب إجازة' || req.type.contains('إجازة');
        bool showRespondButton = false;
        if (isReceived && req.status == 'قيد الانتظار') {
          if (isLeaveRequest) {
            final currentStep = req.extraData?['current_step_order'] != null
                ? (req.extraData!['current_step_order'] is int
                    ? req.extraData!['current_step_order'] as int
                    : int.tryParse(req.extraData!['current_step_order'].toString()) ?? 1)
                : 1;
            if (currentStep == 1 && _session.isDeptHead) {
              final reqDept = req.extraData?['sender_department']?.toString().trim();
              final myDept = _viewModel.currentUserDepartment?.trim();
              if (reqDept != null && myDept != null && reqDept == myDept) {
                showRespondButton = true;
              }
            } else if (currentStep == 2 && _session.isViceDean) {
              showRespondButton = true;
            } else if (currentStep == 3 && _session.isDean) {
              showRespondButton = true;
            } else if (currentStep == 4 && _session.isAdminOrDeanship) {
              showRespondButton = true;
            }
          } else {
            showRespondButton = true;
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        req.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        req.status,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                isReceived
                    ? _buildInfoRow('الجهة المرسلة:', req.senderCollege)
                    : _buildInfoRow('الجهة المستقبلة:', req.destinationCollege),
                const SizedBox(height: 4),
                _buildInfoRow(
                    'مقدم الطلب:',
                    req.applicantName.isNotEmpty
                        ? req.applicantName
                        : 'غير حدد'),
                const SizedBox(height: 4),
                _buildInfoRow('النوع:', req.type),
                if (!isReceived && req.extraData != null &&
                    req.extraData!['current_step_order'] != null &&
                    req.status == 'قيد الانتظار') ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    'الطلب حالياً عند:',
                    _getStepLabel(req.extraData!['current_step_order']),
                  ),
                ],
                if (req.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow('التفاصيل:', req.description),
                ],
                const SizedBox(height: 4),
                _buildInfoRow('الإرسال:', _formatDate(req.dateSent)),
                if (req.extraData != null && req.extraData!['approval_history'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green[100]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تاريخ الموافقات:',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ... (req.extraData!['approval_history'] as List<dynamic>).map((item) {
                          final String role = item['approver_role'] ?? '';
                          final String dateStr = item['date'] ?? '';
                          String formattedTime = '';
                          try {
                            if (dateStr.isNotEmpty) {
                              final dt = DateTime.parse(dateStr);
                              formattedTime = _formatDate(dt);
                            }
                          } catch (_) {}
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'تمت الموافقـة من قبل $role بتاريخ $formattedTime',
                                    style: const TextStyle(color: Colors.green, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                if (req.status == 'مرفوض') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[100]!),
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'تم الرفض بواسطة: ${req.extraData?['rejected_by_role'] ?? 'جهة المراجعة'}${req.dateReplied != null ? ' بتاريخ ${_formatDate(req.dateReplied!)}' : ''}',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 22.0),
                            child: Text('سبب الرفض: ${req.rejectionReason}',
                                style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (req.status == 'تم الرد') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[100]!),
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.reply, color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'تم الرد بواسطة عميد الكلية${req.dateReplied != null ? ' بتاريخ ${_formatDate(req.dateReplied!)}' : ''}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 22.0),
                            child: Text('الرد: ${req.rejectionReason}',
                                style: const TextStyle(color: Colors.green, fontSize: 12)),
                          ),
                        ],
                        if (req.extraData?['reply_attachments'] != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 22.0),
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
                                runSpacing: 8,
                                children: urls.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  String url = entry.value;
                                  return OutlinedButton.icon(
                                    onPressed: () => _openFile(url),
                                    icon: const Icon(Icons.attach_file, size: 12, color: Colors.green),
                                    label: Text('ملف الرد (${idx + 1})', style: const TextStyle(fontSize: 10, color: Colors.green)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: BorderSide(color: Colors.green.shade300),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  );
                                }).toList(),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showRespondButton)
                      ElevatedButton(
                        onPressed: () => _showRespondBottomSheet(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesktopColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('رد'),
                      ),
                    const SizedBox(width: 8),
                    if (req.status == 'مقبول' && isLeaveRequest) ...[
                      ElevatedButton.icon(
                        onPressed: () => _viewLocalLeaveRequest(req),
                        icon: const Icon(Icons.description, color: Colors.white, size: 16),
                        label: const Text('عرض استمارة الطلب الرسمية', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (req.fileUrl != null && req.fileUrl!.isNotEmpty)
                      Builder(builder: (context) {
                        List<String> urls = [];
                        if (req.fileUrl!.startsWith('[')) {
                          try {
                            urls = List<String>.from(jsonDecode(req.fileUrl!));
                          } catch (_) {
                            urls = [req.fileUrl!];
                          }
                        } else {
                          urls = [req.fileUrl!];
                        }

                        return Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: urls.asMap().entries.map((entry) {
                            int idx = entry.key;
                            String url = entry.value;
                            return OutlinedButton.icon(
                              onPressed: () => _openFile(url),
                              icon: const Icon(Icons.file_present, size: 16),
                              label: Text('عرض الملف (${idx + 1})', style: const TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                            );
                          }).toList(),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
