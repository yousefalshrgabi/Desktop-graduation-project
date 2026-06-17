import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/widgets/shared_desktop_app_bar.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

import '../services/college_workload_submission_service.dart';
import 'college_workload_preview_screen.dart';

class CollegeWorkloadRequestsScreen extends StatefulWidget {
  const CollegeWorkloadRequestsScreen({super.key});

  @override
  State<CollegeWorkloadRequestsScreen> createState() => _CollegeWorkloadRequestsScreenState();
}

class _CollegeWorkloadRequestsScreenState extends State<CollegeWorkloadRequestsScreen> {
  final _service = CollegeWorkloadSubmissionService();
  final _session = AppSession();

  @override
  Widget build(BuildContext context) {
    Stream<List<CollegeWorkloadSubmission>> stream;
    if (_session.isDean) {
      stream = _service.getSubmissionsByCollege(_session.userCollege);
    } else if (_session.isAdminOrDeanship) {
      stream = _service.getAllSubmissions();
    } else {
      stream = const Stream.empty();
    }

    return Scaffold(
      appBar: const SharedDesktopAppBar(customTitle: 'اعتماد الأنصبة'),
      body: StreamBuilder<List<CollegeWorkloadSubmission>>(
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
            return const Center(child: Text('لا توجد طلبات اعتماد أنصبة'));
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

  Widget _buildCard(CollegeWorkloadSubmission sub) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: DesktopColors.primary,
          child: Icon(Icons.assignment_turned_in, color: Colors.white),
        ),
        title: Text('اعتماد النصاب المحسوب - الفصل ${sub.term == 'first' ? 'الأول' : 'الثاني'}'),
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
              builder: (context) => CollegeWorkloadPreviewScreen(
                submission: sub,
                canApprove: canApprove,
                isFinalApproval: isFinalApproval,
                onStatusChanged: () => setState(() {}),
              ),
            ),
          );
        },
      ),
    );
  }
}
