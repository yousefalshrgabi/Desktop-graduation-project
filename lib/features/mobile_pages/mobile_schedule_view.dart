import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import '../schedule_screen/screens/department_schedule_screen.dart';
import '../schedule_screen/screens/teachers_schedule_screen.dart';
import '../schedule_screen/screens/rooms_schedule_screen.dart';
import '../schedule_screen/screens/upload_schedule_screen.dart';

class MobileScheduleView extends StatelessWidget {
  final int initialIndex;
  const MobileScheduleView({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final session = AppSession();
    final bool canUpload = session.isViceDean;

    return DefaultTabController(
      length: canUpload ? 4 : 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجداول الدراسية'),
          backgroundColor: const Color(0xFF0123C9),
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'جدول القسم'),
              const Tab(text: 'جدول المعلم'),
              const Tab(text: 'جدول القاعة'),
              if (canUpload) const Tab(text: 'رفع الجدول'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const DepartmentScheduleScreen(),
            const TeachersScheduleScreen(),
            const RoomsScheduleScreen(),
            if (canUpload) const UploadScheduleScreen(),
          ],
        ),
      ),
    );
  }
}
