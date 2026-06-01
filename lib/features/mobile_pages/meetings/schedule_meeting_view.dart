import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/core/widgets/searchable_user_dropdown.dart';
import 'meetings_viewmodel.dart';

import 'package:academic_affairs_management/features/mobile_pages/meetings/meeting_model.dart';

class ScheduleMeetingView extends StatefulWidget {
  final MeetingModel? meeting; // في حالة التعديل، يتم تمرير الاجتماع الحالي

  const ScheduleMeetingView({super.key, this.meeting});

  @override
  State<ScheduleMeetingView> createState() => _ScheduleMeetingViewState();
}

class _ScheduleMeetingViewState extends State<ScheduleMeetingView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _roomController = TextEditingController(); // حقل تحديد قاعة الاجتماع
  
  List<TextEditingController> _agendaControllers = [TextEditingController()];
  List<TextEditingController> _attendeeControllers = [TextEditingController()];
  List<String?> _selectedAttendeeIds = [null];
  List<Map<String, dynamic>> _facultyMembers = [];

  @override
  void initState() {
    super.initState();
    
    // تهيئة البيانات في حال كنا في وضع التعديل
    if (widget.meeting != null) {
      _titleController.text = widget.meeting!.title;
      _dateController.text = widget.meeting!.date;
      _timeController.text = widget.meeting!.time;
      _roomController.text = widget.meeting!.room;
      
      _agendaControllers = widget.meeting!.agenda
          .map((item) => TextEditingController(text: item))
          .toList();
      if (_agendaControllers.isEmpty) {
        _agendaControllers.add(TextEditingController());
      }
      
      _attendeeControllers = widget.meeting!.attendees
          .map((item) => TextEditingController(text: item))
          .toList();
      _selectedAttendeeIds = List<String?>.from(widget.meeting!.attendeeIds);
      
      // التأكد من تطابق حجم القائمتين للحاضرين
      while (_selectedAttendeeIds.length < _attendeeControllers.length) {
        _selectedAttendeeIds.add(null);
      }
      if (_attendeeControllers.isEmpty) {
        _attendeeControllers.add(TextEditingController());
        _selectedAttendeeIds.add(null);
      }
    }
    
    _loadFacultyMembers();
  }

  Future<void> _loadFacultyMembers() async {
    final List<Map<String, dynamic>> temp = [];
    final college = AppSession().userCollege;
    
    // 1. محاولة جلب الأعضاء من قاعدة البيانات المحلية SQLite
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> localUsers = await db.query(
        'users',
        where: 'faculty = ?',
        whereArgs: [college],
      );
      for (final u in localUsers) {
        final name = u['name']?.toString() ?? '';
        final id = u['id']?.toString() ?? '';
        if (name.isNotEmpty && id.isNotEmpty && !temp.any((e) => e['name'] == name)) {
          temp.add({'id': id, 'name': name});
        }
      }
    } catch (e) {
      debugPrint('SQLite error loading faculty: $e');
    }

    // 2. محاولة جلب الأعضاء من قاعدة بيانات Firestore السحابية
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('faculty', isEqualTo: college)
          .get()
          .timeout(const Duration(seconds: 4));
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString() ?? '';
        final id = doc.id;
        if (name.isNotEmpty && !temp.any((e) => e['name'] == name)) {
          temp.add({'id': id, 'name': name});
        }
      }
    } catch (e) {
      debugPrint('Firestore error loading faculty: $e');
    }

    if (mounted) {
      setState(() {
        _facultyMembers = temp;
        
        // ربط المعرفات للحاضرين بناءً على أسمائهم عند انتهاء التحميل في وضع التعديل
        if (widget.meeting != null) {
          for (int i = 0; i < _attendeeControllers.length; i++) {
            if (_selectedAttendeeIds[i] == null) {
              final name = _attendeeControllers[i].text.trim();
              final match = _facultyMembers.firstWhere(
                (m) => m['name'].toString().trim().toLowerCase() == name.toLowerCase(),
                orElse: () => <String, dynamic>{},
              );
              if (match.isNotEmpty && match['id'] != null) {
                _selectedAttendeeIds[i] = match['id'].toString();
              }
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _roomController.dispose();
    for (var c in _agendaControllers) {
      c.dispose();
    }
    for (var c in _attendeeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (mounted) {
          _timeController.text = picked.format(context);
        }
      });
    }
  }

  void _addAgendaField() {
    setState(() {
      _agendaControllers.add(TextEditingController());
    });
  }

  void _removeAgendaField(int index) {
    if (_agendaControllers.length > 1) {
      setState(() {
        _agendaControllers[index].dispose();
        _agendaControllers.removeAt(index);
      });
    }
  }

  void _addAttendeeField() {
    setState(() {
      _attendeeControllers.add(TextEditingController());
      _selectedAttendeeIds.add(null);
    });
  }

  void _removeAttendeeField(int index) {
    if (_attendeeControllers.length > 1) {
      setState(() {
        _attendeeControllers[index].dispose();
        _attendeeControllers.removeAt(index);
        _selectedAttendeeIds.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final agenda = _agendaControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final attendees = _attendeeControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (agenda.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة بند واحد على الأقل لجدول الأعمال.')),
      );
      return;
    }

    if (attendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة حاضر واحد على الأقل.')),
      );
      return;
    }

    // Collect attendee IDs for notifications
    final attendeeIds = <String>[];
    for (int i = 0; i < _attendeeControllers.length; i++) {
      final name = _attendeeControllers[i].text.trim();
      if (name.isNotEmpty) {
        final id = _selectedAttendeeIds[i];
        if (id != null) {
          attendeeIds.add(id);
        } else {
          final match = _facultyMembers.firstWhere(
            (m) => m['name'].toString().trim().toLowerCase() == name.toLowerCase(),
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty && match['id'] != null) {
            attendeeIds.add(match['id'].toString());
          }
        }
      }
    }

    final meetingsViewModel = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = widget.meeting != null
        ? await meetingsViewModel.updateMeeting(
            meetingId: widget.meeting!.id,
            title: _titleController.text.trim(),
            date: _dateController.text.trim(),
            time: _timeController.text.trim(),
            room: _roomController.text.trim(),
            agenda: agenda,
            attendees: attendees,
            attendeeIds: attendeeIds,
          )
        : await meetingsViewModel.scheduleMeeting(
            title: _titleController.text.trim(),
            date: _dateController.text.trim(),
            time: _timeController.text.trim(),
            room: _roomController.text.trim(),
            agenda: agenda,
            attendees: attendees,
            attendeeIds: attendeeIds,
          );

    if (success && mounted) {
      Navigator.pop(context, true);
    } else if (mounted && meetingsViewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsViewModel.errorMessage!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.meeting != null ? 'تعديل تفاصيل الاجتماع' : 'جدولة اجتماع جديد',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section
                  const Text('عنوان الاجتماع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                    decoration: InputDecoration(
                      hintText: 'مثال: الاجتماع الدوري الأول للفصل الدراسي الثاني',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date & Time Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _dateController,
                              readOnly: true,
                              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                              onTap: _selectDate,
                              decoration: InputDecoration(
                                hintText: 'اختر التاريخ',
                                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                prefixIcon: const Icon(Icons.calendar_month),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الوقت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _timeController,
                              readOnly: true,
                              validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                              onTap: _selectTime,
                              decoration: InputDecoration(
                                hintText: 'اختر الوقت',
                                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                prefixIcon: const Icon(Icons.access_time),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // حقل تحديد قاعة الاجتماع
                  const Text('قاعة الاجتماع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _roomController,
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                    decoration: InputDecoration(
                      hintText: 'مثال: قاعة مجلس الكلية، قاعة السمينار، مكتب رئيس القسم',
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      prefixIcon: const Icon(Icons.room),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Agenda Section
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'جدول الأعمال (النقاط للمناقشة)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addAgendaField,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة بند', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _agendaControllers.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _agendaControllers[idx],
                                validator: (v) => idx == 0 && v!.isEmpty ? 'يجب إدخال البند الأول على الأقل' : null,
                                decoration: InputDecoration(
                                  hintText: 'البند ${idx + 1}',
                                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (_agendaControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeAgendaField(idx),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Attendees Section
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'أسماء الحاضرين (أعضاء مجلس القسم)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addAttendeeField,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة حاضر', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attendeeControllers.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SearchableUserDropdown(
                                value: _selectedAttendeeIds[idx],
                                hint: 'اختر اسم العضو ${idx + 1}',
                                items: _facultyMembers,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedAttendeeIds[idx] = val;
                                    final match = _facultyMembers.firstWhere(
                                      (m) => m['id'] == val,
                                      orElse: () => <String, dynamic>{'name': ''},
                                    );
                                    _attendeeControllers[idx].text = match['name'] ?? '';
                                  });
                                },
                              ),
                            ),
                            if (_attendeeControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeAttendeeField(idx),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Consumer<MeetingsViewModel>(
                          builder: (context, vm, child) {
                            return ElevatedButton(
                              onPressed: vm.isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesktopColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: vm.isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      widget.meeting != null ? 'حفظ التعديلات' : 'جدولة الاجتماع',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
