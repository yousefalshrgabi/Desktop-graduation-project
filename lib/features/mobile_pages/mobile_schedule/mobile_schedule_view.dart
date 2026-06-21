import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/department_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/teachers_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/rooms_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/upload_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/students_schedule_screen.dart';
import 'package:academic_affairs_management/features/schedule_screen/screens/custom_groups_schedule_screen.dart';
import 'mobile_schedule_view_model.dart';

class MobileScheduleView extends StatelessWidget {
  final int initialIndex;
  const MobileScheduleView({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final session = AppSession();

    return ChangeNotifierProvider<MobileScheduleViewModel>(
      create: (_) => MobileScheduleViewModel(initialIndex: initialIndex),
      child: Consumer<MobileScheduleViewModel>(
        builder: (context, viewModel, child) {
          final tabs = viewModel.buildTabs(session);
          final views = viewModel.buildViews(
            session,
            studentsView: const StudentsScheduleScreen(),
            teachersView: const TeachersScheduleScreen(),
            departmentView: const DepartmentScheduleScreen(),
            roomsView: const RoomsScheduleScreen(),
            customView: const CustomGroupsScheduleScreen(),
            uploadView: const UploadScheduleScreen(),
          );

          final int length = tabs.length;

          return DefaultTabController(
            length: length,
            initialIndex: viewModel.currentIndex < length ? viewModel.currentIndex : 0,
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
                  onTap: viewModel.updateIndex,
                ),
              ),
              body: TabBarView(
                children: views,
              ),
            ),
          );
        },
      ),
    );
  }
}
