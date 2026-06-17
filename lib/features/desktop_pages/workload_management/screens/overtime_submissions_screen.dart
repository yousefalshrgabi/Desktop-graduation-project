import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

import '../services/college_overtime_submission_service.dart';
import '../models/college_overtime_submission.dart';
import 'college_overtime_preview_screen.dart';

class OvertimeSubmissionsScreen extends StatefulWidget {
  const OvertimeSubmissionsScreen({super.key});

  @override
  State<OvertimeSubmissionsScreen> createState() => _OvertimeSubmissionsScreenState();
}

class _OvertimeSubmissionsScreenState extends State<OvertimeSubmissionsScreen> {
  final _service = CollegeOvertimeSubmissionService();
  final _session = AppSession();

  @override
  Widget build(BuildContext context) {
    Stream<List<CollegeOvertimeSubmission>> stream;
    if (_session.isDean) {
      stream = _service.getSubmissionsByCollege(_session.userCollege);
    } else if (_session.isAdminOrDeanship) {
      stream = _service.getAllSubmissions();
    } else {
      stream = const Stream.empty();
    }

    return Scaffold(
      appBar: const SharedDesktopAppBar(customTitle: 'اعتماد الساعات الزائدة والموازية'),
      body: StreamBuilder<List<CollegeOvertimeSubmission>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final allSubmissions = snapshot.data ?? [];
          
          final filteredSubmissions = allSubmissions.where((sub) {
            if (_session.isAdminOrDeanship) {
              // النيابة ترى فقط ما وصل إليها (أو ما اعتمدته) ولا ترى ما تم رفضه
              return sub.status == 'pending_vice_chancellor' || sub.status == 'approved';
            } else if (_session.isDean) {
              // العميد يرى ما عنده، وما رفعه للنيابة، وما تم اعتماده نهائياً، ولا يرى المرفوض
              return sub.status == 'pending_dean' || sub.status == 'pending_vice_chancellor' || sub.status == 'approved';
            }
            return false;
          }).toList();

          if (filteredSubmissions.isEmpty) {
            return const Center(child: Text('لا توجد طلبات اعتماد للساعات الزائدة/الموازية'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredSubmissions.length,
            itemBuilder: (context, index) {
              final sub = filteredSubmissions[index];
              return _buildCard(sub);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(CollegeOvertimeSubmission sub) {
    final dateStr = sub.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(sub.createdAt!) : '';
    
    String statusText;
    Color statusColor;
    switch (sub.status) {
      case 'pending_dean':
        statusText = 'بانتظار اعتماد العميد';
        statusColor = Colors.orange;
        break;
      case 'pending_vice_chancellor':
        statusText = 'بانتظار اعتماد النيابة';
        statusColor = Colors.orange.shade700;
        break;
      case 'approved':
        statusText = 'تم الاعتماد النهائي';
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

    bool canApprove = false;
    bool isFinalApproval = false;
    if (_session.isDean && sub.status == 'pending_dean') canApprove = true;
    if (_session.isAdminOrDeanship && sub.status == 'pending_vice_chancellor') {
      canApprove = true;
      isFinalApproval = true;
    }

    final typeName = sub.type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: DesktopColors.primary,
          child: Icon(Icons.access_time, color: Colors.white),
        ),
        title: Text('اعتماد كشوفات $typeName - الفصل ${sub.term == 'first' ? 'الأول' : 'الثاني'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('الكلية: ${sub.collegeName}'),
            Text('تاريخ الرفع: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CollegeOvertimePreviewScreen(submission: sub),
            ),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }

  void _showActionDialog(CollegeOvertimeSubmission sub, bool isFinalApproval) {
    final typeName = sub.type == 'overtime' ? 'الساعات الزائدة' : 'الساعات الموازية';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('اعتماد كشوفات $typeName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكلية: ${sub.collegeName}'),
            const SizedBox(height: 16),
            Text('هل تود اعتماد هذا الطلب ${isFinalApproval ? 'بشكل نهائي' : 'ورفعه لنيابة رئاسة الجامعة'}؟'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleReject(sub.id, isFinalApproval);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('رفض الطلب'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleApprove(sub.id, isFinalApproval);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('اعتماد الطلب'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(String id, bool isFinalApproval) async {
    try {
      if (isFinalApproval) {
        await _service.approveByDeanship(id);
      } else {
        await _service.approveByDean(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد الطلب بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject(String id, bool isFinalApproval) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض هنا...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (isFinalApproval) {
        await _service.rejectByDeanship(id, reasonController.text.trim());
      } else {
        await _service.rejectByDean(id, reasonController.text.trim());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
