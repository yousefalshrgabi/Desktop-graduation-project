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
            color: statusColor.withValues(alpha: 0.1),
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
}
