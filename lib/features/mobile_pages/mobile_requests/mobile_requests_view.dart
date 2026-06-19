import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/requests_screen/request_view_model.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileRequestsView extends StatefulWidget {
  const MobileRequestsView({super.key});

  @override
  State<MobileRequestsView> createState() => _MobileRequestsViewState();
}

class _MobileRequestsViewState extends State<MobileRequestsView> {
  final RequestViewModel _viewModel = RequestViewModel();
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
    );
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
                    color: Colors.black.withOpacity(0.3),
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
          heroTag: null,
          onPressed: _showNewRequestBottomSheet,
          backgroundColor: DesktopColors.primary,
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
                _buildInfoRow(
                    'مقدم الطلب:',
                    req.applicantName.isNotEmpty
                        ? req.applicantName
                        : 'غير حدد'),
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
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
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
      },
    );
  }
}
