import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';

class MobileScheduleViewModel extends ChangeNotifier {
  final int initialIndex;
  late int currentIndex;

  MobileScheduleViewModel({this.initialIndex = 0}) {
    currentIndex = initialIndex;
  }

  void updateIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  List<Tab> buildTabs(AppSession session) {
    final bool isViceDean = session.isViceDean;
    final List<Tab> tabs = [
      const Tab(text: 'الطلاب'),
      const Tab(text: 'المعلم'),
      const Tab(text: 'القسم'),
      const Tab(text: 'القاعة'),
      const Tab(text: 'مخصصة'),
    ];
    if (isViceDean) {
      tabs.add(const Tab(text: 'رفع الجدول'));
    }
    return tabs;
  }

  List<Widget> buildViews(AppSession session, {
    required Widget studentsView,
    required Widget teachersView,
    required Widget departmentView,
    required Widget roomsView,
    required Widget customView,
    required Widget uploadView,
  }) {
    final bool isViceDean = session.isViceDean;
    final List<Widget> views = [
      studentsView,
      teachersView,
      departmentView,
      roomsView,
      customView,
    ];
    if (isViceDean) {
      views.add(uploadView);
    }
    return views;
  }
}
