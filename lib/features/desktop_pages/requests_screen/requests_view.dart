import 'dart:io';

import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
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

  Future<void> _openFile(RequestModel request) async {
    String? path = request.localFilePath;
    String? url = request.fileUrl;

    if ((path == null || path.isEmpty) && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد ملف مرفق')),
      );
      return;
    }
    
    Uri uri;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      uri = Uri.file(path);
    } else if (url != null && url.isNotEmpty) {
      // إذا لم يكن موجوداً محلياً، نقوم بتحميله أولاً
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحميل الملف للمرة الأولى للوصول إليه مستقبلاً بدون إنترنت...')),
      );
      String? downloadedPath = await _viewModel.downloadFile(request);
      if (downloadedPath != null) {
        uri = Uri.file(downloadedPath);
      } else {
        // إذا فشل التحميل لسبب ما، نحاول فتحه مباشرة من الرابط كحل أخير
        uri = Uri.parse(url);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملف المرفق غير متاح محلياً ولا يوجد رابط سحابي')),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الملف')),
        );
      }
    }
  }

  void _showRespondDialog(RequestModel request) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('الرد على: ${request.title}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('مقدم الطلب:', request.applicantName.isNotEmpty ? request.applicantName : 'غير محدد'),
                  const SizedBox(height: 8),
                  _buildInfoRow('الكلية:', request.senderCollege),
                  const SizedBox(height: 8),
                  _buildInfoRow('نوع الطلب:', request.type),
                  const SizedBox(height: 8),
                  const Text('تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Text(request.description.isNotEmpty ? request.description : 'لا توجد تفاصيل إضافية'),
                  ),
                  const SizedBox(height: 16),
                  if (request.fileUrl != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _openFile(request),
                      icon: const Icon(Icons.attach_file),
                      label: const Text('فتح الملف المرفق للاطلاع'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoRow('وقت الاستلام:', _formatDate(request.dateSent)),
                  const SizedBox(height: 16),
                  const Text('سبب الرفض (مطلوب في حالة الرفض فقط):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب الرفض هنا...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                Navigator.pop(context);
                bool success = await _viewModel.respondToRequest(
                  request.id,
                  'مقبول',
                );
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_viewModel.errorMessage)),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showNewRequestDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedDestination = 'نيابة الشؤون الأكاديمية';
    String selectedType = 'طلب اجازة مرضية';
    PlatformFile? selectedFile;
    
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
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('إنشاء طلب جديد'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'عنوان الطلب',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedDestination,
                        decoration: InputDecoration(
                          labelText: 'الجهة الموجه إليها',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ['جميع الكليات', 'كلية الهندسة', 'كلية الحاسبات', 'كلية العلوم', 'نيابة الشؤون الأكاديمية']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedDestination = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'نوع الطلب',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: requestTypes
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'تفاصيل أو ملاحظات حول الطلب',
                          hintText: 'اكتب تفاصيل إضافية هنا...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedFile != null 
                                  ? 'الملف المختيار: ${selectedFile!.name}' 
                                  : 'لم يتم اختيار ملف بعد',
                                style: TextStyle(
                                  color: selectedFile != null ? Colors.blue[800] : Colors.grey,
                                  fontWeight: selectedFile != null ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selectedFile != null)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() => selectedFile = null);
                                },
                              ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final file = await _viewModel.pickFile();
                                if (file != null) {
                                  setDialogState(() => selectedFile = file);
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('اختيار ملف'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesktopColors.primary,
                                foregroundColor: Colors.white,
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
                    Navigator.pop(statefulContext);
                    
                    bool success = await _viewModel.sendRequest(
                      title: titleController.text.trim(),
                      destinationCollege: selectedDestination,
                      type: selectedType,
                      description: descriptionController.text.trim(),
                      attachedFile: selectedFile,
                    );
                    
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
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
          }
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
                            icon: const Icon(Icons.refresh, color: DesktopColors.primary),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }
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
        if (req.status == 'مرفوض') statusColor = Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        req.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('الجهة المرسلة:', req.senderCollege)),
                    Expanded(child: _buildInfoRow('مقدم الطلب:', req.applicantName.isNotEmpty ? req.applicantName : 'غير محدد')),
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
                  Text('التفاصيل: ${req.description}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('الاستلام: ${_formatDate(req.dateSent)}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: req.dateReplied != null
                          ? Row(
                              children: [
                                const Icon(Icons.done_all, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('الرد: ${_formatDate(req.dateReplied!)}'),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
                if (req.status == 'مرفوض' && req.rejectionReason != null)
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
                          const Icon(Icons.info_outline, color: Colors.red, size: 18),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (req.fileUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => _openFile(req),
                        icon: const Icon(Icons.visibility),
                        label: const Text('فتح الملف المرفق'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[800],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('الجهة: ${req.destinationCollege} | الحالة: ${req.status}'),
            leading: CircleAvatar(
              backgroundColor: req.status == 'مقبول' ? Colors.green : (req.status == 'مرفوض' ? Colors.red : Colors.orange),
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
                    _buildInfoRow('التفاصيل:', req.description.isNotEmpty ? req.description : 'لا توجد'),
                    const SizedBox(height: 8),
                    _buildInfoRow('تاريخ الإرسال:', _formatDate(req.dateSent)),
                    if (req.dateReplied != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('تاريخ الرد:', _formatDate(req.dateReplied!)),
                    ],
                    if (req.status == 'مرفوض' && req.rejectionReason != null) ...[
                      const SizedBox(height: 8),
                      Text('سبب الرفض: ${req.rejectionReason}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    if (req.fileUrl != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _openFile(req),
                          icon: const Icon(Icons.file_download),
                          label: const Text('فتح/تحميل الملف المرسل'),
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
