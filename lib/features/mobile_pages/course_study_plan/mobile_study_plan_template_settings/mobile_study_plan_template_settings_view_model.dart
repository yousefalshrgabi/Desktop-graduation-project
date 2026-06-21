import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/course_study_plan_service.dart';
import '../models/course_study_plan_model.dart';

class MobileStudyPlanTemplateSettingsViewModel extends ChangeNotifier {
  final _service = CourseStudyPlanService();
  final yearController = TextEditingController();
  final List<TextEditingController> weekControllers = List.generate(
    14,
    (_) => TextEditingController(),
  );

  String _term = 'first';
  String get term => _term;

  bool _loading = true;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  bool _exporting = false;
  bool get exporting => _exporting;

  void disposeControllers() {
    yearController.dispose();
    for (final controller in weekControllers) {
      controller.dispose();
    }
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final settings = await _service.loadSettings(_term);
      yearController.text = settings.academicYear;
      for (var i = 0; i < weekControllers.length; i++) {
        weekControllers[i].text =
            i < settings.weekRanges.length ? settings.weekRanges[i] : '';
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  CourseStudyPlanTemplateSettings _collectSettings() {
    return CourseStudyPlanTemplateSettings(
      term: _term,
      academicYear: yearController.text.trim(),
      weekRanges: weekControllers.map((c) => c.text.trim()).toList(),
      updatedBy: FirebaseAuth.instance.currentUser?.email ?? '',
    );
  }

  Future<void> changeTerm(String val) async {
    if (val == _term) return;
    _term = val;
    notifyListeners();
    await load();
  }

  Future<void> save() async {
    _saving = true;
    notifyListeners();
    try {
      await _service.saveSettings(_collectSettings());
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> export() async {
    _exporting = true;
    notifyListeners();
    try {
      await _service.exportTemplateSettingsDocx(
        _collectSettings(),
        collegeName: '',
      );
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }
}
