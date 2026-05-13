import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'programs_model.dart';
import 'programs_viewmodel.dart';

class EditProgramDialog extends StatefulWidget {
  final ProgramModel program;
  final ProgramsViewModel viewModel;

  const EditProgramDialog({super.key, required this.program, required this.viewModel});

  @override
  State<EditProgramDialog> createState() => _EditProgramDialogState();
}

class _EditProgramDialogState extends State<EditProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _arNameCtrl;
  late TextEditingController _enNameCtrl;
  late TextEditingController _levelsCtrl;

  late List<ProgramTrack> _tracks;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _arNameCtrl = TextEditingController(text: widget.program.nameAr);
    _enNameCtrl = TextEditingController(text: widget.program.nameEn);
    _levelsCtrl = TextEditingController(text: widget.program.totalLevels.toString());
    _tracks = List.from(widget.program.tracks);
  }

  @override
  void dispose() {
    _arNameCtrl.dispose();
    _enNameCtrl.dispose();
    _levelsCtrl.dispose();
    super.dispose();
  }

  void _addTrack() {
    final arCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final levelCtrl = TextEditingController(text: '3');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مسار جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: arCtrl, decoration: const InputDecoration(labelText: 'اسم المسار بالعربي')),
            const SizedBox(height: 8),
            TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'اسم المسار بالإنجليزي')),
            const SizedBox(height: 8),
            TextField(controller: levelCtrl, decoration: const InputDecoration(labelText: 'يبدأ من المستوى'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (arCtrl.text.isNotEmpty && enCtrl.text.isNotEmpty) {
                setState(() {
                  _tracks.add(ProgramTrack(
                    trackId: DateTime.now().millisecondsSinceEpoch.toString(),
                    nameAr: arCtrl.text,
                    nameEn: enCtrl.text,
                    startsAtLevel: int.tryParse(levelCtrl.text) ?? 3,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ المسار'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(DesktopSpacing.lg),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تعديل البرنامج الأكاديمي', style: DesktopTextStyles.heading2),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: DesktopSpacing.md),
                
                _buildTextField('اسم البرنامج (عربي)', _arNameCtrl, Icons.school),
                const SizedBox(height: DesktopSpacing.md),
                _buildTextField('اسم البرنامج (إنجليزي)', _enNameCtrl, Icons.school_outlined),
                const SizedBox(height: DesktopSpacing.md),
                _buildTextField('عدد المستويات', _levelsCtrl, Icons.format_list_numbered, isNumeric: true),
                
                const SizedBox(height: DesktopSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مسارات البرنامج:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addTrack,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة مسار'),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                _tracks.isEmpty 
                    ? const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد مسارات مضافة بعد.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(track.nameAr),
                              subtitle: Text('${track.nameEn} • يبدأ بالمستوى: ${track.startsAtLevel}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() => _tracks.removeAt(index));
                                },
                              ),
                            ),
                          );
                        },
                      ),

                const SizedBox(height: DesktopSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: DesktopSpacing.sm),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProgram,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('تحديث بيانات البرنامج', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      validator: (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveProgram() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      widget.program.nameAr = _arNameCtrl.text.trim();
      widget.program.nameEn = _enNameCtrl.text.trim();
      widget.program.totalLevels = int.tryParse(_levelsCtrl.text.trim()) ?? 4;
      widget.program.tracks = _tracks;
      
      await widget.viewModel.updateProgram(widget.program);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تعديل البرنامج بنجاح'), backgroundColor: Colors.orange),
        );
      }
    }
  }
}
