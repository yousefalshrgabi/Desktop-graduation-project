import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/department_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/teachers_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/rooms_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/upload_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/students_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/custom_groups_schedule_screen.dart';

class MobileScheduleView extends StatelessWidget {
  final int initialIndex;
  const MobileScheduleView({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final session = AppSession();
    final bool isViceDean = session.isViceDean;
    final bool isDeptHead = session.isDeptHead;
    
    // Default is just faculty member
    final bool isJustFaculty = !isViceDean && !isDeptHead;

    final List<Widget> tabs = [
      const Tab(text: 'الطلاب'),
      const Tab(text: 'المعلم'),
      const Tab(text: 'القسم'),
      const Tab(text: 'القاعة'),
      const Tab(text: 'مخصصة'),
    ];

    final List<Widget> views = [
      const StudentsScheduleScreen(),
      const TeachersScheduleScreen(),
      const DepartmentScheduleScreen(),
      const RoomsScheduleScreen(),
      const CustomGroupsScheduleScreen(),
    ];

    if (isViceDean) {
      tabs.add(const Tab(text: 'رفع الجدول'));
      views.add(const UploadScheduleScreen());
    }

    final int length = tabs.length;

    return DefaultTabController(
      length: length,
      initialIndex: initialIndex < length ? initialIndex : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجداول الدراسية'),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: views,
        ),
      ),
    );
  }
}
