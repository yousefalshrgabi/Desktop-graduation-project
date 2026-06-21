import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/models/incentive_entry.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/computed_nasab_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/incentive_word_export_service.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/services/computed_nasab_print_service.dart';

class MobileMyScheduleViewModel extends ChangeNotifier {
  final _nasabService = ComputedNasabService();

  String term = 'first';
  bool loading = true;
  bool exporting = false;
  List<IncentiveEntry> myNasab = [];
  String errorMessage = '';

  MobileMyScheduleViewModel() {
    loadData();
  }

  Future<void> loadData() async {
    loading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final session = AppSession();
      final college = session.userCollege;
      final userName = session.userName.trim();

      if (college.isEmpty || userName.isEmpty) {
        errorMessage = 'بيانات الكلية أو المستخدم غير مكتملة.';
        loading = false;
        notifyListeners();
        return;
      }

      final allEntries = await _nasabService.buildEntries(
        collegeName: college,
        term: term,
      );

      myNasab = allEntries.where((e) {
        return e.teacherName.trim().toLowerCase() == userName.toLowerCase() ||
               e.teacherName.toLowerCase().contains(userName.toLowerCase());
      }).toList();

      loading = false;
    } catch (e) {
      errorMessage = 'تعذر تحميل النصاب: $e';
      loading = false;
    }
    notifyListeners();
  }

  void setTerm(String value) {
    term = value;
    loadData();
  }

  Future<bool> exportData(String action) async {
    final college = AppSession().userCollege;
    final teacherName = AppSession().userName;

    if (college.isEmpty) {
      errorMessage = 'الكلية غير محددة';
      notifyListeners();
      return false;
    }

    exporting = true;
    errorMessage = '';
    notifyListeners();
    bool success = false;

    try {
      if (action == 'word') {
        final exportService = IncentiveWordExportService();
        await exportService.exportTeacherNasab(
          teacherName: teacherName,
          entries: myNasab,
        );
        success = true;
      } else if (action == 'pdf') {
        final printService = ComputedNasabPrintService();
        final termLabel = term == 'first' ? 'الفصل الأول' : 'الفصل الثاني';
        await printService.printEntries(
          title: 'نصاب محسوب — $college — $termLabel',
          entries: myNasab,
          teacherFilter: teacherName,
        );
        success = true;
      }
    } catch (e) {
      errorMessage = 'تعذر التصدير: $e';
    } finally {
      exporting = false;
      notifyListeners();
    }
    return success;
  }
}
