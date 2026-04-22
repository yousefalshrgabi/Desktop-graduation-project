import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'subjects_view_model.dart';
import 'subject_model.dart';

class SubjectsView extends StatefulWidget {
  const SubjectsView({super.key});

  @override
  State<SubjectsView> createState() => _SubjectsViewState();
}

class _SubjectsViewState extends State<SubjectsView> {
  final SubjectsViewModel _viewModel = SubjectsViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesktopSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: DesktopSpacing.lg),
                _buildFiltersRow(context),
                const SizedBox(height: DesktopSpacing.md),
                _buildTable(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إدارة المواد الدراسية', style: DesktopTextStyles.heading1),
        const SizedBox(height: 4),
        Text('عرض، إضافة، وتعديل المواد الدراسية في النظام',
            style: DesktopTextStyles.caption),
      ],
    );
  }

  Widget _buildFiltersRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            onChanged: _viewModel.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'ابحث باسم المادة (عربي أو إنجليزي)...',
              prefixIcon: const Icon(Icons.search),
              enabledBorder:
                  DesktopInputTheme.inputDecorationTheme.enabledBorder,
              focusedBorder:
                  DesktopInputTheme.inputDecorationTheme.focusedBorder,
            ),
          ),
        ),
        const SizedBox(width: DesktopSpacing.md),
        ElevatedButton(
          onPressed: () => _showAddDialog(context),
          style: DesktopButtonTheme.elevatedButtonTheme.style,
          child: Row(
            children: const [
              Icon(Icons.add, color: DesktopColors.surface),
              SizedBox(width: 8),
              Text('إضافة مادة جديدة'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: Builder(builder: (_) {
        if (_viewModel.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (_viewModel.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DesktopSpacing.lg),
              child: Text('حدث خطأ: ${_viewModel.errorMessage}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        if (_viewModel.filteredSubjects.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(DesktopSpacing.lg),
              child: Text('لا توجد مواد مسجلة حالياً'),
            ),
          );
        }

        return CustomDataTable(
          columns: const [
            DataColumn(
                label: Text('المعرف', style: DesktopTextStyles.caption)),
            DataColumn(
                label: Text('الاسم (عربي)', style: DesktopTextStyles.caption)),
            DataColumn(
                label:
                    Text('الاسم (إنجليزي)', style: DesktopTextStyles.caption)),
            DataColumn(
                label: Text('إجراءات', style: DesktopTextStyles.caption)),
          ],
          rows: _viewModel.filteredSubjects.map((subject) {
            return DataRow(cells: [
              DataCell(Text(
                '#${subject.id.substring(0, 5)}...',
                style: DesktopTextStyles.caption,
              )),
              DataCell(Text(subject.arName, style: DesktopTextStyles.body)),
              DataCell(Text(subject.enName, style: DesktopTextStyles.body)),
              DataCell(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, subject);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, subject);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('تعديل', style: TextStyle(color: Colors.orange)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        );
      }),
    );
  }

  // ── Add Dialog ────────────────────────────────────────────────────────────
  void _showAddDialog(BuildContext context) {
    final arCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(DesktopSpacing.lg),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إضافة مادة جديدة',
                            style: DesktopTextStyles.heading1),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.md),

                    // ── الاسمان جنباً إلى جنب ────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('اسم المادة (عربي)'),
                              _textField(
                                controller: arCtrl,
                                hint: 'الاسم بالعربية',
                                icon: Icons.book_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'مطلوب'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('اسم المادة (إنجليزي)'),
                              _textField(
                                controller: enCtrl,
                                hint: 'English name',
                                icon: Icons.book_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: DesktopSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء',
                                style: TextStyle(color: Colors.grey))),
                        const SizedBox(width: DesktopSpacing.xs),
                        ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setS(() => loading = true);
                                  try {
                                    await _viewModel.addSubject(
                                      arName: arCtrl.text,
                                      enName: enCtrl.text,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('تم إضافة المادة بنجاح'),
                                              backgroundColor: Colors.green));
                                    }
                                  } catch (e) {
                                    setS(() => loading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('خطأ: $e'),
                                              backgroundColor: Colors.red));
                                    }
                                  }
                                },
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('حفظ البيانات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit Dialog ───────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, SubjectModel subject) {
    final arCtrl = TextEditingController(text: subject.arName);
    final enCtrl = TextEditingController(text: subject.enName);
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(DesktopSpacing.lg),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تعديل المادة',
                            style: DesktopTextStyles.heading1),
                        IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: DesktopSpacing.md),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('اسم المادة (عربي)'),
                              _textField(
                                controller: arCtrl,
                                hint: 'الاسم بالعربية',
                                icon: Icons.book_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'مطلوب'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: DesktopSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('اسم المادة (إنجليزي)'),
                              _textField(
                                controller: enCtrl,
                                hint: 'English name',
                                icon: Icons.book_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: DesktopSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إلغاء',
                                style: TextStyle(color: Colors.grey))),
                        const SizedBox(width: DesktopSpacing.xs),
                        ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setS(() => loading = true);
                                  try {
                                    await _viewModel.updateSubject(
                                      subject.id,
                                      arName: arCtrl.text,
                                      enName: enCtrl.text,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('تم تحديث المادة بنجاح'),
                                              backgroundColor: Colors.blue));
                                    }
                                  } catch (e) {
                                    setS(() => loading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('خطأ: $e'),
                                              backgroundColor: Colors.red));
                                    }
                                  }
                                },
                          style: DesktopButtonTheme.elevatedButtonTheme.style,
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('حفظ التعديلات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete Dialog ─────────────────────────────────────────────────────────
  void _showDeleteDialog(BuildContext context, SubjectModel subject) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف مادة "${subject.arName}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _viewModel.deleteSubject(subject.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم حذف المادة بنجاح'),
                  backgroundColor: Colors.red));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        enabledBorder: DesktopInputTheme.inputDecorationTheme.enabledBorder,
        focusedBorder: DesktopInputTheme.inputDecorationTheme.focusedBorder,
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
