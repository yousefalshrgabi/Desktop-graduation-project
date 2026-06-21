import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

import 'screens/department_schedule_screen.dart';
import 'screens/teachers_schedule_screen.dart';
import 'screens/rooms_schedule_screen.dart';

/// الشاشة الرئيسية لنظام الجداول - تحتوي على تبويبات لكل نوع
class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DesktopSpacing.lg, DesktopSpacing.lg, DesktopSpacing.lg, 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: DesktopColors.primary, size: 28),
                    const SizedBox(width: 10),
                    const Text('نظام الجداول الدراسية',
                        style: DesktopTextStyles.heading1),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'عرض وتصدير الجداول حسب القسم أو المعلم أو القاعة',
                  style: DesktopTextStyles.caption
                      .copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: DesktopSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesktopColors.border),
                  ),
                  child: TabBar(
                    indicatorColor: DesktopColors.primary,
                    labelColor: DesktopColors.primary,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(icon: Icon(Icons.school_outlined), text: 'جدول القسم'),
                      Tab(icon: Icon(Icons.person_outlined), text: 'جدول المعلم'),
                      Tab(icon: Icon(Icons.meeting_room_outlined), text: 'جدول القاعة'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // محتوى التبويبات
          const Expanded(
            child: TabBarView(
              children: [
                DepartmentScheduleScreen(),
                TeachersScheduleScreen(),
                RoomsScheduleScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
