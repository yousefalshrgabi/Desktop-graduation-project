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
                    value: selectedDestination,
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
                    value: selectedType,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'leave_request_fab',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LeaveRequestScreen())),
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.description_outlined, color: Colors.white),
              label: const Text('طلب إجازة رسمية',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'new_request_fab',
              onPressed: _showNewRequestBottomSheet,
              backgroundColor: DesktopColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label:
                  const Text('طلب جديد', style: TextStyle(color: Colors.white)),
            ),
          ],
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isReceived && req.status == 'قيد الانتظار')
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
                if (req.type == 'استمارة طلب إجازة' ||
                    req.type.contains('إجازة') ||
                    req.type.contains('اجازة'))
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
                if (req.fileUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _openFile(req.fileUrl),
                    icon: const Icon(Icons.file_present),
                    label: const Text('عرض الملف'),
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
