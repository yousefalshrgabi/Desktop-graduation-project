import 'package:flutter/material.dart';

import '../models/study_plan.dart';

/// Confirms deletion of a full study plan from Firestore.
Future<bool> confirmDeleteStudyPlan(
  BuildContext context,
  StudyPlanSummary plan,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف الخطة الدراسية'),
      content: Text(
        'هل تريد حذف الخطة بالكامل من التطبيق؟ (سيتم مزامنة الحذف لاحقاً مع السحابة)\n\n'
        '${plan.collegeName}\n'
        '${plan.displayTitle}\n'
        '(${plan.courseCount} مقرر)\n\n'
        'لا يمكن التراجع عن هذا الإجراء.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حذف نهائياً'),
        ),
      ],
    ),
  );
  return result == true;
}
