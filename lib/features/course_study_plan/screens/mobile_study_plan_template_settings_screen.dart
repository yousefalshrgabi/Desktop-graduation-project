import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';

import '../services/course_study_plan_service.dart';
import '../models/course_study_plan_model.dart';

class MobileStudyPlanTemplateSettingsScreen extends StatefulWidget {
  const MobileStudyPlanTemplateSettingsScreen({super.key});

  @override
  State<MobileStudyPlanTemplateSettingsScreen> createState() =>
      _MobileStudyPlanTemplateSettingsScreenState();
}

class _MobileStudyPlanTemplateSettingsScreenState
    extends State<MobileStudyPlanTemplateSettingsScreen> {
  final _service = CourseStudyPlanService();
  final _yearController = TextEditingController();
  final List<TextEditingController> _weekControllers = List.generate(
    14,
    (_) => TextEditingController(),
  );

  String _term = 'first';
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _yearController.dispose();
    for (final controller in _weekControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _service.loadSettings(_term);
      _yearController.text = settings.academicYear;
      for (var i = 0; i < _weekControllers.length; i++) {
        _weekControllers[i].text =
            i < settings.weekRanges.length ? settings.weekRanges[i] : '';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CourseStudyPlanTemplateSettings _collectSettings() {
    return CourseStudyPlanTemplateSettings(
      term: _term,
      academicYear: _yearController.text.trim(),
      weekRanges: _weekControllers.map((c) => c.text.trim()).toList(),
      updatedBy: FirebaseAuth.instance.currentUser?.email ?? '',
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveSettings(_collectSettings());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ كليشة الخطة الدراسية بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _service.exportTemplateSettingsDocx(
        _collectSettings(),
        collegeName: '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ نسخة الكليشة المحدّثة بنجاح.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ ملف الكليشة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعداد كليشة الخطط الدراسية'),
          backgroundColor: DesktopColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'البيانات العامة للكليشة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _term,
                            decoration: const InputDecoration(
                              labelText: 'الفصل الدراسي',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'first',
                                child: Text('الفصل الأول'),
                              ),
                              DropdownMenuItem(
                                value: 'second',
                                child: Text('الفصل الثاني'),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value == null || value == _term) return;
                              setState(() => _term = value);
                              await _load();
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _yearController,
                            decoration: const InputDecoration(
                              labelText: 'العام الجامعي',
                              hintText: '2026-2027',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'املأ عمود التاريخ (من-إلى) لكل أسبوع كما سيظهر في الكليشة.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تواريخ الأسابيع',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < _weekControllers.length; i++) ...[
                            TextField(
                              controller: _weekControllers[i],
                              minLines: 2,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'الأسبوع ${i + 1}',
                                hintText: '10-14\nسبتمبر 2023م',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _exporting ? null : _export,
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('تحميل الكليشة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving || _exporting ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text('حفظ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
