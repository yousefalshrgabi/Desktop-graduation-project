import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/desktop_theme.dart';
import 'mobile_study_plan_template_settings_view_model.dart';

class MobileStudyPlanTemplateSettingsView extends StatefulWidget {
  const MobileStudyPlanTemplateSettingsView({super.key});

  @override
  State<MobileStudyPlanTemplateSettingsView> createState() =>
      _MobileStudyPlanTemplateSettingsViewState();
}

class _MobileStudyPlanTemplateSettingsViewState
    extends State<MobileStudyPlanTemplateSettingsView> {
  late MobileStudyPlanTemplateSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MobileStudyPlanTemplateSettingsViewModel();
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.disposeControllers();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await _viewModel.save();
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
    }
  }

  Future<void> _export() async {
    try {
      await _viewModel.export();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MobileStudyPlanTemplateSettingsViewModel>(
        builder: (context, vm, child) {
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
                    onPressed: vm.loading ? null : () => vm.load(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              body: vm.loading
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
                                  value: vm.term,
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
                                  onChanged: (value) {
                                    if (value != null) {
                                      vm.changeTerm(value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: vm.yearController,
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
                                for (var i = 0; i < vm.weekControllers.length; i++) ...[
                                  TextField(
                                    controller: vm.weekControllers[i],
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
                          onPressed: vm.saving || vm.exporting ? null : _export,
                          icon: vm.exporting
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
                          onPressed: vm.saving || vm.exporting ? null : _save,
                          icon: vm.saving
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
        },
      ),
    );
  }
}
