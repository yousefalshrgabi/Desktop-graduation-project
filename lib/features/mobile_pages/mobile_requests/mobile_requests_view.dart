import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:academic_affairs_management/features/desktop_pages/workload_management/models/college_overtime_submission.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/college_overtime_submission_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/screens/college_overtime_preview_screen.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/college_workload_submission_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/screens/college_workload_preview_screen.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/course_need_letter_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/screens/course_need_preview_screen.dart';
import 'package:academic_affairs_management/features/mobile_pages/leave_request_screen.dart'
    show LeaveRequestScreen;
import 'package:academic_affairs_management/features/mobile_pages/general_request_screen.dart'
    show GeneralRequestScreen;

class MobileRequestsView extends StatefulWidget {
  const MobileRequestsView({super.key});

  @override
  State<MobileRequestsView> createState() => _MobileRequestsViewState();
}

class _MobileRequestsViewState extends State<MobileRequestsView> {
  final RequestViewModel _viewModel = RequestViewModel();
  final _session = AppSession();
  final _overtimeService = CollegeOvertimeSubmissionService();
  final _workloadService = CollegeWorkloadSubmissionService();
  final _courseNeedService = CourseNeedLetterService();

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
    _viewModel.loadColleges();
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

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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

  void _showAttachmentsDialog(RequestModel req) {
    List<String> urls = [];
    if (req.fileUrl != null && req.fileUrl!.isNotEmpty) {
      try {
        final decoded = jsonDecode(req.fileUrl!);
        if (decoded is List) {
          urls = List<String>.from(decoded);
        } else {
          urls = [req.fileUrl!];
        }
      } catch (e) {
        urls = [req.fileUrl!];
      }
    }

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد ملفات مرفقة')),
      );
      return;
    }

    if (urls.length == 1) {
      _openFile(urls.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الملفات المرفقة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: urls.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.attach_file, color: DesktopColors.primary),
                title: Text('مرفق ${index + 1}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFile(urls[index]);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showNewRequestBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختر نوع الطلب الجديد',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.beach_access, color: Colors.teal),
                  title: const Text('طلب إجازة رسمية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استمارة لتقديم طلب إجازة'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.mail_outline, color: DesktopColors.primary),
                  title: const Text('طلب عام', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('ارسال طلب مع تفاصيله مع ارفاق ملفات'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GeneralRequestScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.school_outlined, color: Colors.blueGrey),
                  title: const Text('طلب تفرغ علمي (كشكل)', style: TextStyle(color: Colors.grey)),
                  subtitle: const Text('طلب تفرغ علمي للبحث أو الدراسة (عرض تجريبي)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('طلب تفرغ علمي (متاح كعرض تجريبي فقط في هذه النسخة)'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.blueGrey),
                  title: const Text('طلب ترقية علمية إلى درجة البكالوريوس (كشكل)', style: TextStyle(color: Colors.grey)),
                  subtitle: const Text('طلب ترقية أكاديمية وظيفية (عرض تجريبي)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('طلب ترقية علمية إلى درجة البكالوريوس (متاح كعرض تجريبي فقط في هذه النسخة)'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
                  const Text('الكلية المرسل إليها:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCollege,
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
                          const SnackBar(
                              content:
                                  Text('تم الإرسال بنجاح إلى عميد الكلية')),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
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
            final isProsecutionType = request.type == 'طلب من النيابة العامة';
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
                    if (request.fileUrl != null && request.fileUrl!.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () => _showAttachmentsDialog(request),
                        icon: const Icon(Icons.visibility),
                        label: const Text('عرض المرفقات'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: isProsecutionType ? 'نص الرد' : 'سبب الرفض (مطلوب للرفض فقط)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 2,
                    ),
                    if (isProsecutionType) ...[
                      const SizedBox(height: 16),
                      const Text('إرفاق ملفات مع الرد (اختياري):',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
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
                                  icon: const Icon(Icons.attach_file,
                                      size: 14),
                                  label: const Text('إرفاق ملفات',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () async {
                                    final result =
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
                                      setState(
                                          () => replyFiles = result.files);
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
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 14, color: Colors.red),
                                        onPressed: () => setState(
                                            () => replyFiles.remove(f)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isProsecutionType)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال الرد',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () async {
                          if (reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('الرجاء كتابة نص الرد أولاً')),
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
                      )
                    else
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
        body: StreamBuilder<List<CollegeWorkloadSubmission>>(
          stream: (_session.isDean || _session.isViceDean)
              ? _workloadService.getAllSubmissions()
              : const Stream.empty(),
          builder: (context, snapshotWorkload) {
            final allWorkloads = snapshotWorkload.data ?? [];
            return StreamBuilder<List<CollegeOvertimeSubmission>>(
              stream: _overtimeService.getAllSubmissions(),
              builder: (context, snapshotOvertimes) {
                final allOvertimes = snapshotOvertimes.data ?? [];

                return StreamBuilder<List<SavedCourseNeedLetter>>(
                  stream: (_session.isDean ||
                          _session.isViceDean ||
                          _session.isAdminOrDeanship)
                      ? _courseNeedService.watchLetters()
                      : const Stream.empty(),
                  builder: (context, snapshotNeeds) {
                    final allNeedLetters = snapshotNeeds.data ?? [];
                    final needsInbox = <dynamic>[];
                    final needsOutbox = <dynamic>[];
                    final currentUid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';

                    for (final ot in allOvertimes) {
                      final isSameCollege =
                          ot.collegeName == _session.userCollege;
                      final isMySubmission = ot.createdByUid == currentUid;

                      if (_session.isDean && isSameCollege) {
                        if (ot.status == 'pending_dean') {
                          needsInbox.add(ot);
                        } else {
                          needsOutbox.add(ot);
                        }
                      } else if (_session.isAdminOrDeanship) {
                        if (ot.status == 'pending_vice_chancellor') {
                          needsInbox.add(ot);
                        } else if (ot.status == 'approved') {
                          needsOutbox.add(ot);
                        }
                      } else if (_session.isViceDean &&
                          isSameCollege &&
                          isMySubmission) {
                        needsOutbox.add(ot);
                      }
                    }

                    // معالجة طلبات النصاب المحسوب (للعميد ونائب العميد فقط)
                    for (final wl in allWorkloads) {
                      if (wl.collegeName != _session.userCollege) continue;

                      if (_session.isDean) {
                        if (wl.status == 'pending_dean') {
                          needsInbox.add(wl); // العميد: وارد يحتاج اعتماده
                        } else {
                          needsOutbox.add(wl); // العميد: صادر للمتابعة
                        }
                      } else if (_session.isViceDean) {
                        needsOutbox.add(
                            wl); // نائب العميد: صادرة فقط لجميع طلبات كليته
                      }
                    }

                    // معالجة خطابات احتياج المقررات
                    for (final nl in allNeedLetters) {
                      final isSameCollege =
                          nl.collegeName == _session.userCollege;
                      final isMySubmission = nl.createdByUid == currentUid;

                      if (_session.isDean && isSameCollege) {
                        if (nl.status == 'pending_dean') {
                          needsInbox.add(nl);
                        } else {
                          needsOutbox.add(nl);
                        }
                      } else if (_session.isAdminOrDeanship) {
                        if (nl.status == 'pending_academic_affairs' ||
                            nl.status == 'pending_vice_chancellor') {
                          needsInbox.add(nl);
                        } else if (nl.status == 'approved' ||
                            nl.status == 'rejected_by_academic_affairs') {
                          needsOutbox.add(nl);
                        }
                      } else if (_session.isViceDean &&
                          isSameCollege &&
                          isMySubmission) {
                        needsOutbox.add(nl);
                      }
                    }

                    return AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            TabBarView(
                              children: [
                                _buildCombinedList(
                                  requests: _viewModel.receivedRequests,
                                  needs: needsInbox,
                                  isReceived: true,
                                ),
                                _buildCombinedList(
                                  requests: _viewModel.sentRequests,
                                  needs: needsOutbox,
                                  isReceived: false,
                                ),
                              ],
                            ),
                            if (_viewModel.isSending || _viewModel.isLoading)
                              Container(
                                color: Colors.black.withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                          color: Colors.white),
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
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'new_request_fab',
          onPressed: () {
            if (_session.isAdminOrDeanship) {
              _showProsecutionRequestBottomSheet();
            } else {
              _showNewRequestBottomSheet();
            }
          },
          backgroundColor: DesktopColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('طلب جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCombinedList({
    required List<RequestModel> requests,
    required List<dynamic> needs,
    required bool isReceived,
  }) {
    if (requests.isEmpty && needs.isEmpty) {
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

    final combinedItems = <dynamic>[];
    combinedItems.addAll(requests);
    combinedItems.addAll(needs);

    combinedItems.sort((a, b) {
      DateTime dateA;
      if (a is RequestModel)
        dateA = a.dateSent;
      else if (a is CollegeOvertimeSubmission)
        dateA = a.createdAt ?? DateTime(2000);
      else if (a is CollegeWorkloadSubmission)
        dateA = a.createdAt ?? DateTime(2000);
      else if (a is SavedCourseNeedLetter)
        dateA = a.createdAt ?? DateTime(2000);
      else
        dateA = DateTime(2000);

      DateTime dateB;
      if (b is RequestModel)
        dateB = b.dateSent;
      else if (b is CollegeOvertimeSubmission)
        dateB = b.createdAt ?? DateTime(2000);
      else if (b is CollegeWorkloadSubmission)
        dateB = b.createdAt ?? DateTime(2000);
      else if (b is SavedCourseNeedLetter)
        dateB = b.createdAt ?? DateTime(2000);
      else
        dateB = DateTime(2000);

      return dateB.compareTo(dateA);
    });

    final items = <Widget>[];
    for (final item in combinedItems) {
      if (item is RequestModel) {
        items.add(_buildRequestCard(item, isReceived));
      } else if (item is CollegeOvertimeSubmission) {
        items.add(_buildOvertimeCard(item, isReceived));
      } else if (item is CollegeWorkloadSubmission) {
        items.add(_buildWorkloadCard(item, isReceived));
      } else if (item is SavedCourseNeedLetter) {
        items.add(_buildNeedLetterCard(item, isReceived));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: items,
    );
  }

  Widget _buildRequestCard(RequestModel req, bool isReceived) {
    Color statusColor = Colors.orange;
    if (req.status == 'مقبول') statusColor = Colors.green;
    if (req.status == 'مرفوض') statusColor = Colors.red;
    if (req.status == 'تم الرد') statusColor = Colors.blue;

    bool showRespondButton = false;
    if (isReceived && req.status == 'قيد الانتظار') {
      final bool isLeave = req.type == 'استمارة طلب إجازة' ||
          req.type.contains('إجازة') ||
          req.type.contains('اجازة') ||
          req.type == 'طلب عام';
      if (isLeave) {
        final int currentStep = req.extraData?['current_step_order'] != null
            ? (req.extraData!['current_step_order'] is int
                ? req.extraData!['current_step_order'] as int
                : int.tryParse(req.extraData!['current_step_order'].toString()) ?? 1)
            : 1;

        if (currentStep == 1 && _session.isDeptHead) {
          final reqDept = req.extraData?['sender_department']?.toString().trim();
          final myDept = (_session.userDepartment ?? '').trim();
          if (reqDept != null && myDept.isNotEmpty && _viewModel.isSameDepartment(reqDept, myDept)) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
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
            _buildInfoRow('مقدم الطلب:',
                req.applicantName.isNotEmpty ? req.applicantName : 'غير حدد'),
            const SizedBox(height: 4),
            _buildInfoRow('النوع:', req.type),
            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildInfoRow('التفاصيل:', req.description),
            ],
            const SizedBox(height: 4),
            _buildInfoRow('الإرسال:', _formatDate(req.dateSent)),
            if (!isReceived && req.type != 'طلب من النيابة العامة') ...[
              const SizedBox(height: 4),
              _buildInfoRow('عند من الطلب الآن:', _getCurrentStepOwner(req)),
            ],
            if (req.dateReplied != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow('الرد:', _formatDate(req.dateReplied!)),
            ],
            if (req.status == 'مرفوض' && req.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8)),
                child: Text('سبب الرفض: ${req.rejectionReason}',
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
            if (req.status == 'تم الرد' && req.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.reply, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('الرد: ${req.rejectionReason}',
                              style: const TextStyle(color: Colors.blue, fontSize: 13)),
                        ),
                      ],
                    ),
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
                          runSpacing: 8,
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
                              label: Text('ملف الرد (${idx + 1})', style: const TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
            if (req.extraData != null &&
                req.extraData!['approval_history'] != null) ...[
              const SizedBox(height: 8),
              _buildApprovalHistoryWidget(req.extraData!['approval_history']),
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
                if ((req.type == 'استمارة طلب إجازة' ||
                        req.type.contains('إجازة') ||
                        req.type.contains('اجازة')) &&
                    req.status == 'مقبول')
                  ElevatedButton.icon(
                    onPressed: () => _exportLocalLeaveRequest(req),
                    icon: const Icon(Icons.file_download,
                        color: Colors.white, size: 16),
                    label: const Text('تصدير الاستمارة',
                        style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                const SizedBox(width: 8),
                if (req.fileUrl != null && req.fileUrl!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _showAttachmentsDialog(req),
                    icon: const Icon(Icons.file_present),
                    label: const Text('المرفقات'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatIsoDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  String _getCurrentStepOwner(RequestModel req) {
    if (req.status == 'مقبول') return 'تم الاعتماد النهائي';
    if (req.status == 'مرفوض') {
      final rejectorRole = req.extraData?['rejected_by_role'] ?? 'الجهة المستقبلة';
      return 'تم الرفض من قبل $rejectorRole';
    }
    
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

  Widget _buildApprovalHistoryWidget(dynamic historyRaw) {
    List<dynamic> history = [];
    if (historyRaw is List) {
      history = historyRaw;
    } else if (historyRaw is String) {
      try {
        history = jsonDecode(historyRaw);
      } catch (_) {}
    }

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجل سير الموافقات:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => const Divider(height: 8),
            itemBuilder: (context, index) {
              final step = history[index];
              if (step is! Map) return const SizedBox.shrink();

              final role = step['approver_role'] ?? step['role'] ?? 'غير معروف';
              final name = step['approver_name'] ?? step['name'] ?? 'غير معروف';
              final dateStr = step['date'] ?? step['timestamp'] ?? '';
              final formattedDate = dateStr.isNotEmpty ? _formatIsoDate(dateStr) : '';

              return Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      role,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOvertimeCard(CollegeOvertimeSubmission sub, bool isReceived) {
    final typeName =
        sub.type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CollegeOvertimePreviewScreen(submission: sub),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: DesktopColors.primary,
                    radius: 20,
                    child:
                        Icon(Icons.access_time, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اعتماد كشوفات $typeName',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'الكلية: ${sub.collegeName}',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'حالة الطلب: ${sub.status == 'pending_dean' ? 'بانتظار اعتماد العميد' : sub.status == 'pending_vice_chancellor' ? 'بانتظار اعتماد النيابة' : sub.status == 'approved' ? 'تم الاعتماد النهائي' : 'مرفوض'}',
                  style: TextStyle(
                    color: sub.status == 'pending_dean'
                        ? Colors.orange
                        : (sub.status == 'approved'
                            ? Colors.green
                            : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedLetterCard(SavedCourseNeedLetter sub, bool isReceived) {
    String statusText;
    Color statusColor;
    switch (sub.status) {
      case 'pending_dean':
        statusText =
            isReceived ? 'وارد — يحتاج اعتمادك' : 'صادر — بانتظار العميد';
        statusColor = Colors.orange;
        break;
      case 'pending_academic_affairs':
      case 'pending_vice_chancellor':
        statusText = 'صادر — بانتظار الشؤون/النيابة';
        statusColor = Colors.orange.shade700;
        break;
      case 'approved':
        statusText = 'معتمد نهائياً';
        statusColor = Colors.green;
        break;
      case 'rejected_by_dean':
      case 'rejected_by_academic_affairs':
      case 'rejected':
        statusText = 'مرفوض';
        statusColor = Colors.red;
        break;
      default:
        statusText = sub.status;
        statusColor = Colors.grey;
    }

    final termLabel = sub.term == 'first' ? 'الأول' : 'الثاني';
    final canTap = isReceived && sub.status == 'pending_dean';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canTap
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseNeedPreviewScreen(
                      savedLetter: sub,
                      collegeName: sub.collegeName,
                      term: sub.term,
                      data: sub.data,
                    ),
                  ),
                ).then((_) => setState(() {}))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'خطاب مقررات احتياج',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isReceived) Text('الجهة المرسلة: كلية ${sub.collegeName}'),
              Text('الفصل: $termLabel'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkloadCard(CollegeWorkloadSubmission sub, bool isReceived) {
    String statusText;
    Color statusColor;
    switch (sub.status) {
      case 'pending_dean':
        statusText =
            isReceived ? 'وارد — يحتاج اعتمادك' : 'صادر — بانتظار العميد';
        statusColor = Colors.orange;
        break;
      case 'pending_vice_chancellor':
        statusText = 'صادر — بانتظار النيابة';
        statusColor = Colors.orange.shade700;
        break;
      case 'approved':
        statusText = 'معتمد نهائياً';
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusText = 'مرفوض';
        statusColor = Colors.red;
        break;
      default:
        statusText = sub.status;
        statusColor = Colors.grey;
    }

    final termLabel = sub.term == 'first' ? 'الأول' : 'الثاني';
    final canTap = isReceived && sub.status == 'pending_dean';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canTap
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CollegeWorkloadPreviewScreen(
                      submission: sub,
                      canApprove: true,
                      isFinalApproval: false,
                      onStatusChanged: () => setState(() {}),
                    ),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: DesktopColors.primary,
                    radius: 20,
                    child: Icon(Icons.assignment_turned_in,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'النصاب المحسوب — الفصل $termLabel',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'الكلية: ${sub.collegeName}',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (sub.rejectionReason != null &&
                  sub.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'سبب الرفض: ${sub.rejectionReason}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
              if (canTap) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'اضغط للاعتماد أو الرفض',
                    style: TextStyle(
                      color: DesktopColors.primary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
