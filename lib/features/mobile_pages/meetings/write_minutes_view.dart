import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'meeting_model.dart';
import 'meetings_viewmodel.dart';


class WriteMinutesView extends StatefulWidget {
  final MeetingModel meeting;

  const WriteMinutesView({super.key, required this.meeting});

  @override
  State<WriteMinutesView> createState() => _WriteMinutesViewState();
}

class _WriteMinutesViewState extends State<WriteMinutesView> {
  final _minutesController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _localSaving = false;
  final AppSession _session = AppSession();

  // Form controllers
  final _monthController = TextEditingController();
  final _deptController = TextEditingController();
  final _collegeController = TextEditingController();
  final _yearController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _dayController = TextEditingController();
  final _chairmanNameController = TextEditingController();
  final _updatesController = TextEditingController();
  final _endTimeController = TextEditingController();

  final Map<String, TextEditingController> _attendeeRoleControllers = {};
  final List<TextEditingController> _agendaDiscussionControllers = [];
  final List<TextEditingController> _agendaDecisionControllers = [];
  final List<TextEditingController> _agendaDecisionNumberControllers = [];
  final List<TextEditingController> _agendaDecisionYearControllers = [];

  @override
  void initState() {
    super.initState();

    // Initialize basic info defaults
    _monthController.text = _getDefaultMonth();
    _deptController.text = widget.meeting.departmentId;
    _collegeController.text = widget.meeting.college;
    _yearController.text = _getDefaultAcademicYear();
    _locationController.text = widget.meeting.room;
    _dateController.text = widget.meeting.date;
    _timeController.text = widget.meeting.time;
    _dayController.text = _getDefaultDayName();
    _chairmanNameController.text = _session.userName.isNotEmpty
        ? _session.userName
        : (widget.meeting.attendees.isNotEmpty ? widget.meeting.attendees.first : '');
    _updatesController.text = '';
    _endTimeController.text = '';

    // Initialize lists
    for (final att in widget.meeting.attendees) {
      final isChairman = att == _chairmanNameController.text;
      _attendeeRoleControllers[att] = TextEditingController(text: isChairman ? 'رئيس المجلس' : 'عضو');
    }

    for (int i = 0; i < widget.meeting.agenda.length; i++) {
      _agendaDiscussionControllers.add(TextEditingController());
      _agendaDecisionControllers.add(TextEditingController());
      _agendaDecisionNumberControllers.add(TextEditingController(text: '${i + 1}'));
      _agendaDecisionYearControllers.add(TextEditingController(text: _getCurrentYear()));
    }

    // Load existing minutes text
    _minutesController.text = widget.meeting.minutes;

    // Parse existing minutes text if not empty
    if (widget.meeting.minutes.isNotEmpty) {
      _parseExistingMinutes(widget.meeting.minutes);
    } else {
      // If minutes are empty, pre-generate the compiled text initially
      _updateCompiledMinutes();
    }

    // Set up listeners to auto-update compiled minutes when form inputs change
    _monthController.addListener(_updateCompiledMinutes);
    _deptController.addListener(_updateCompiledMinutes);
    _collegeController.addListener(_updateCompiledMinutes);
    _yearController.addListener(_updateCompiledMinutes);
    _locationController.addListener(_updateCompiledMinutes);
    _dateController.addListener(_updateCompiledMinutes);
    _timeController.addListener(_updateCompiledMinutes);
    _dayController.addListener(_updateCompiledMinutes);
    _chairmanNameController.addListener(_updateCompiledMinutes);
    _updatesController.addListener(_updateCompiledMinutes);
    _endTimeController.addListener(_updateCompiledMinutes);

    for (final controller in _attendeeRoleControllers.values) {
      controller.addListener(_updateCompiledMinutes);
    }
    for (final controller in _agendaDiscussionControllers) {
      controller.addListener(_updateCompiledMinutes);
    }
    for (final controller in _agendaDecisionControllers) {
      controller.addListener(_updateCompiledMinutes);
    }
    for (final controller in _agendaDecisionNumberControllers) {
      controller.addListener(_updateCompiledMinutes);
    }
    for (final controller in _agendaDecisionYearControllers) {
      controller.addListener(_updateCompiledMinutes);
    }
    _fetchHodDepartment();
  }

  @override
  void dispose() {
    _monthController.dispose();
    _deptController.dispose();
    _collegeController.dispose();
    _yearController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _dayController.dispose();
    _chairmanNameController.dispose();
    _updatesController.dispose();
    _endTimeController.dispose();

    for (final controller in _attendeeRoleControllers.values) {
      controller.dispose();
    }
    for (final controller in _agendaDiscussionControllers) {
      controller.dispose();
    }
    for (final controller in _agendaDecisionControllers) {
      controller.dispose();
    }
    for (final controller in _agendaDecisionNumberControllers) {
      controller.dispose();
    }
    for (final controller in _agendaDecisionYearControllers) {
      controller.dispose();
    }

    _minutesController.dispose();
    super.dispose();
  }

  String _getDefaultMonth() {
    int monthNum = DateTime.now().month;
    try {
      final parts = widget.meeting.date.split('-');
      if (parts.length >= 2) {
        monthNum = int.tryParse(parts[1]) ?? monthNum;
      }
    } catch (_) {}
    return _getArabicMonthName(monthNum);
  }

  String _getArabicMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'يناير';
  }

  String _getDefaultAcademicYear() {
    final year = DateTime.now().year;
    return '${year - 1}/$year';
  }

  String _getCurrentYear() {
    return '${DateTime.now().year}';
  }

  String _getDefaultDayName() {
    try {
      final parsedDate = DateTime.tryParse(widget.meeting.date);
      if (parsedDate != null) {
        return _getArabicDayName(parsedDate);
      }
    } catch (_) {}
    return 'الأحد';
  }

  String _getArabicDayName(DateTime date) {
    const days = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
    ];
    return days[date.weekday - 1];
  }

  void _parseExistingMinutes(String text) {
    if (text.isEmpty || !text.contains('بسم الله الرحمن الرحيم')) {
      return;
    }

    try {
      // 1. Month
      final monthReg = RegExp(r'محضر الاجتماع الدوري لشهر\s+(.*?)\s+لمجلس قسم');
      final monthMatch = monthReg.firstMatch(text);
      if (monthMatch != null) {
        _monthController.text = monthMatch.group(1)!.trim();
      }

      // 2. Department
      final deptReg = RegExp(r'لمجلس قسم\s+(.*?)$', multiLine: true);
      final deptMatch = deptReg.firstMatch(text);
      if (deptMatch != null) {
        _deptController.text = deptMatch.group(1)!.trim();
      }

      // 3. College & Academic Year
      final collegeReg = RegExp(r'كلية\s+(.*?)\s+–\s+للعام\s+(.*?)$', multiLine: true);
      final collegeMatch = collegeReg.firstMatch(text);
      if (collegeMatch != null) {
        _collegeController.text = collegeMatch.group(1)!.trim();
        _yearController.text = collegeMatch.group(2)!.trim();
      }

      // 4. Location
      final locReg = RegExp(r'المكان:\s+(.*?)$', multiLine: true);
      final locMatch = locReg.firstMatch(text);
      if (locMatch != null) {
        _locationController.text = locMatch.group(1)!.trim();
      }

      // 5. Date
      final dateReg = RegExp(r'التاريخ:\s+(.*?)$', multiLine: true);
      final dateMatch = dateReg.firstMatch(text);
      if (dateMatch != null) {
        _dateController.text = dateMatch.group(1)!.trim();
      }

      // 6. Time
      final timeReg = RegExp(r'الزمان:\s+(.*?)$', multiLine: true);
      final timeMatch = timeReg.firstMatch(text);
      if (timeMatch != null) {
        _timeController.text = timeMatch.group(1)!.trim();
      }

      // 7. Day
      final dayReg = RegExp(r'اليوم:\s+(.*?)$', multiLine: true);
      final dayMatch = dayReg.firstMatch(text);
      if (dayMatch != null) {
        _dayController.text = dayMatch.group(1)!.trim();
      }

      // 8. Chairman
      final chairmanReg = RegExp(r'افتتح\s+(.*?)\s+–\s+رئيس المجلس');
      final chairmanMatch = chairmanReg.firstMatch(text);
      if (chairmanMatch != null) {
        _chairmanNameController.text = chairmanMatch.group(1)!.trim();
      }

      // 9. Attendees Roles
      final attendeesStartIndex = text.indexOf('حضور أعضاء المجلس التالية أسماؤهم:');
      final agendaStartIndex = text.indexOf('نقاط الاجتماع:');
      if (attendeesStartIndex != -1 && agendaStartIndex != -1) {
        final attendeesBlock = text.substring(attendeesStartIndex, agendaStartIndex);
        final lines = attendeesBlock.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.contains('حضور أعضاء')) continue;
          final parts = trimmed.split(' - ');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final role = parts[1].trim();
            for (final att in widget.meeting.attendees) {
              if (att.contains(name) || name.contains(att)) {
                _attendeeRoleControllers[att]?.text = role;
              }
            }
          }
        }
      }

      // 10. Discussions & Decisions for each agenda item
      for (int i = 0; i < widget.meeting.agenda.length; i++) {
        final agendaTitle = widget.meeting.agenda[i];
        final titleMarker = 'عنوان النقطة: $agendaTitle';
        final startIdx = text.indexOf(titleMarker);
        if (startIdx != -1) {
          int endIdx = text.indexOf('عنوان النقطة:', startIdx + titleMarker.length);
          if (endIdx == -1) {
            endIdx = text.indexOf('المستجدات:', startIdx + titleMarker.length);
          }
          if (endIdx != -1) {
            final block = text.substring(startIdx + titleMarker.length, endIdx).trim();
            final decisionReg = RegExp(
                r'قرار المجلس رقم\s+\((.*?)\/(.*?)\)\s+بشأن\s+.*?:?\s*\n\s*أقر المجلس\s+(.*?)\.?$',
                multiLine: true);
            final decisionMatch = decisionReg.firstMatch(block);
            if (decisionMatch != null) {
              final decNum = decisionMatch.group(1)!.trim();
              final decYear = decisionMatch.group(2)!.trim();
              final decisionText = decisionMatch.group(3)!.trim();

              _agendaDecisionNumberControllers[i].text = decNum;
              _agendaDecisionYearControllers[i].text = decYear;
              _agendaDecisionControllers[i].text = decisionText;

              final decStartIdx = block.indexOf('قرار المجلس رقم');
              if (decStartIdx != -1) {
                _agendaDiscussionControllers[i].text = block.substring(0, decStartIdx).trim();
              } else {
                _agendaDiscussionControllers[i].text = block;
              }
            } else {
              _agendaDiscussionControllers[i].text = block;
            }
          }
        }
      }

      // 11. Updates
      final updatesStartIndex = text.indexOf('المستجدات:');
      final conclusionStartIndex = text.indexOf('ختام الاجتماع:');
      if (updatesStartIndex != -1 && conclusionStartIndex != -1) {
        final updatesBlock = text.substring(updatesStartIndex + 'المستجدات:'.length, conclusionStartIndex).trim();
        if (updatesBlock != 'لا توجد مستجدات.') {
          _updatesController.text = updatesBlock;
        }
      }

      // 12. End Time
      final endTimeReg = RegExp(r'انتهى الاجتماع الساعة\s+(.*?)\.');
      final endTimeMatch = endTimeReg.firstMatch(text);
      if (endTimeMatch != null) {
        _endTimeController.text = endTimeMatch.group(1)!.trim();
      }
    } catch (e) {
      debugPrint('Error parsing existing minutes: $e');
    }
  }

  Future<void> _fetchHodDepartment() async {
    if (_session.isDeptHead && _session.userId.isNotEmpty) {
      String? deptName;
      // 1. Try local SQLite
      try {
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> result = await db.query(
          'departments',
          columns: ['name'],
          where: 'hod_id = ?',
          whereArgs: [_session.userId],
          limit: 1,
        );
        if (result.isNotEmpty && result.first['name'] != null) {
          deptName = result.first['name'].toString();
          debugPrint('[MEETINGS HOD] Found department name locally: $deptName');
        }
      } catch (e) {
        debugPrint('[MEETINGS HOD] SQLite error fetching HOD department: $e');
      }

      // 2. Try Firebase Firestore fallback
      if (deptName == null || deptName.isEmpty) {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('departments')
              .where('hod_id', isEqualTo: _session.userId)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 4));
          if (querySnapshot.docs.isNotEmpty) {
            deptName = querySnapshot.docs.first.data()['name']?.toString();
            debugPrint('[MEETINGS HOD] Found department name from Firestore: $deptName');
          }
        } catch (e) {
          debugPrint('[MEETINGS HOD] Firestore error fetching HOD department: $e');
        }
      }

      // 3. Try AppSession fallback
      if ((deptName == null || deptName.isEmpty) && _session.userDepartment.isNotEmpty) {
        deptName = _session.userDepartment;
        debugPrint('[MEETINGS HOD] Using AppSession userDepartment fallback: $deptName');
      }

      if (deptName != null && deptName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _deptController.text = deptName!;
          });
        }
      }
    }
  }


  void _updateCompiledMinutes() {
    final buffer = StringBuffer();
    buffer.writeln('بسم الله الرحمن الرحيم');
    buffer.writeln('محضر الاجتماع الدوري لشهر ${_monthController.text.trim()} لمجلس قسم ${_deptController.text.trim()}');
    buffer.writeln('كلية ${_collegeController.text.trim()} – للعام ${_yearController.text.trim()}');
    buffer.writeln('المكان: ${_locationController.text.trim()}');
    buffer.writeln('التاريخ: ${_dateController.text.trim()}');
    buffer.writeln('الزمان: ${_timeController.text.trim()}');
    buffer.writeln('اليوم: ${_dayController.text.trim()}');
    buffer.writeln();
    buffer.writeln('الحاضرون:');
    buffer.writeln(
        'عقد مجلس قسم ${_deptController.text.trim()} اجتماعه الدوري لشهر ${_monthController.text.trim()} يوم ${_dayController.text.trim()} الموافق ${_dateController.text.trim()} بحضور أعضاء المجلس التالية أسماؤهم:');

    for (final att in widget.meeting.attendees) {
      final role = _attendeeRoleControllers[att]?.text.trim() ?? 'عضو';
      buffer.writeln('$att - $role');
    }

    buffer.writeln();
    buffer.writeln('نقاط الاجتماع:');
    for (int i = 0; i < widget.meeting.agenda.length; i++) {
      buffer.writeln('${i + 1}. ${widget.meeting.agenda[i]}');
    }

    buffer.writeln();
    buffer.writeln('سير الاجتماع:');
    buffer.writeln(
        'افتتح ${_chairmanNameController.text.trim()} – رئيس المجلس – الاجتماع بالبسملة والحمد والصلاة على النبي محمد ﷺ، مرحباً بجميع الحاضرين، ثم بدأ المجلس بمناقشة النقاط المدرجة في جدول الأعمال:');
    buffer.writeln();

    for (int i = 0; i < widget.meeting.agenda.length; i++) {
      final agendaTitle = widget.meeting.agenda[i];
      final discussion = _agendaDiscussionControllers[i].text.trim();
      final decision = _agendaDecisionControllers[i].text.trim();
      final decNum = _agendaDecisionNumberControllers[i].text.trim();
      final decYear = _agendaDecisionYearControllers[i].text.trim();

      buffer.writeln('عنوان النقطة: $agendaTitle');
      buffer.writeln(discussion.isNotEmpty ? discussion : 'تمت مناقشة هذه النقطة واستعراض بنودها.');

      if (decision.isNotEmpty) {
        buffer.writeln('قرار المجلس رقم ($decNum/$decYear) بشأن $agendaTitle:');
        buffer.writeln('أقر المجلس $decision.');
      }
      buffer.writeln();
    }

    buffer.writeln('المستجدات:');
    final updatesInput = _updatesController.text.trim();
    buffer.writeln(updatesInput.isNotEmpty ? updatesInput : 'لا توجد مستجدات.');
    buffer.writeln();

    buffer.writeln('ختام الاجتماع:');
    buffer.writeln('انتهى الاجتماع الساعة ${_endTimeController.text.trim()}.');
    buffer.writeln();

    buffer.writeln('التوقيع:');
    buffer.writeln(_chairmanNameController.text.trim());
    buffer.writeln('رئيس المجلس');

    final compiledText = buffer.toString();
    if (_minutesController.text != compiledText) {
      _minutesController.text = compiledText;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم اختيار الملف: ${_selectedFile!.name}')),
        );
      }
    }
  }

  Future<void> _exportDocx() async {
    if (_minutesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة محتوى المحضر أولاً قبل التصدير.')),
      );
      return;
    }

    setState(() => _localSaving = true);
    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.exportMinutesToDocx(widget.meeting, _minutesController.text.trim());
    setState(() => _localSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير وحفظ ملف Word بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'فشل تصدير ملف Word.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _localSaving = true);
    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.saveMinutesDraft(
      widget.meeting.id, 
      _minutesController.text.trim(),
      departmentId: widget.meeting.departmentId.isNotEmpty 
          ? widget.meeting.departmentId 
          : _session.userDepartment,
    );
    setState(() => _localSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ المسودة بنجاح.'),
          backgroundColor: DesktopColors.primary,
        ),
      );
    }
  }

  Future<void> _submitForApproval() async {
    if (_minutesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة تفاصيل المحضر أولاً.')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار/تصدير ملف المحضر المرفوع (.docx / .pdf) أولاً للتقديم.')),
      );
      return;
    }

    final vm = Provider.of<MeetingsViewModel>(context, listen: false);
    final success = await vm.uploadAndSubmitMinutes(
      meeting: widget.meeting,
      file: _selectedFile!,
      minutesText: _minutesController.text.trim(),
      departmentId: widget.meeting.departmentId.isNotEmpty 
          ? widget.meeting.departmentId 
          : _session.userDepartment,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تقديم المحضر بنجاح إلى نائب العميد للمراجعة.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'فشلت عملية التقديم.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: DesktopColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Cairo',
            color: DesktopColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController? controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
    bool dense = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 8 : 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('كتابة وتوثيق محضر الاجتماع', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: DesktopColors.primary,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
              tabs: [
                Tab(text: 'النموذج الذكي للمحضر', icon: Icon(Icons.playlist_add_check, size: 20)),
                Tab(text: 'محرر النص النهائي', icon: Icon(Icons.description, size: 20)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // ── Tab 1: النموذج الذكي للمحضر ──
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. البيانات الأساسية
                    _buildSectionHeader('أولاً: البيانات الأساسية للاجتماع', Icons.info_outline),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _monthController,
                                    label: 'الشهر الدوري للاجتماع',
                                    hint: 'مثال: يونيو',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _yearController,
                                    label: 'العام الجامعي',
                                    hint: 'مثال: 2025/2026',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _dayController,
                                    label: 'اليوم',
                                    hint: 'مثال: الأحد',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _endTimeController,
                                    label: 'وقت انتهاء الاجتماع',
                                    hint: 'مثال: 12:30 ظهراً',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _locationController,
                                    label: 'المكان / القاعة',
                                    hint: 'مثال: قاعة مجلس القسم',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _chairmanNameController,
                                    label: 'رئيس المجلس',
                                    hint: 'مثال: د. محمد بن أحمد',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _deptController,
                                    label: 'القسم',
                                    hint: 'مثال: علوم الحاسب',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _collegeController,
                                    label: 'الكلية',
                                    hint: 'مثال: الحاسبات وتقنية المعلومات',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _dateController,
                                    label: 'التاريخ',
                                    hint: 'مثال: 2026-06-19',
                                    enabled: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _timeController,
                                    label: 'الزمان / وقت البدء',
                                    hint: 'مثال: 10:00 صباحاً',
                                    enabled: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. الحاضرون وصفاتهم
                    if (widget.meeting.attendees.isNotEmpty) ...[
                      _buildSectionHeader('ثانياً: قائمة الحاضرين وصفاتهم', Icons.people_outline),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.meeting.attendees.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (context, idx) {
                              final name = widget.meeting.attendees[idx];
                              final roleController = _attendeeRoleControllers[name];
                              return Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.grey, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      controller: roleController,
                                      label: 'الصفة / الدور',
                                      hint: 'مثال: رئيس القسم / عضو',
                                      dense: true,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3. سير الاجتماع والقرارات
                    _buildSectionHeader('ثالثاً: سير الاجتماع ونقاشات جدول الأعمال', Icons.gavel_outlined),
                    const SizedBox(height: 12),
                    ...List.generate(widget.meeting.agenda.length, (idx) {
                      final agendaPoint = widget.meeting.agenda[idx];
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: DesktopColors.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'بند ${idx + 1}: $agendaPoint',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: DesktopColors.primary,
                                    fontSize: 13,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _agendaDiscussionControllers[idx],
                                label: 'تفاصيل النقاش والمداولات',
                                hint: 'اكتب هنا تفاصيل ما دار في نقاش هذا البند...',
                                maxLines: 4,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _agendaDecisionControllers[idx],
                                label: 'قرار المجلس المرتبط (اختياري)',
                                hint: 'اكتب نص القرار إذا تم اتخاذ قرار بشأن هذا البند...',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _agendaDecisionNumberControllers[idx],
                                      label: 'رقم القرار',
                                      hint: 'مثال: 1',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _agendaDecisionYearControllers[idx],
                                      label: 'سنة القرار',
                                      hint: 'مثال: 2026',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),

                    // 4. المستجدات
                    _buildSectionHeader('رابعاً: ما يستجد من أعمال ومستجدات', Icons.notification_important_outlined),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildTextField(
                          controller: _updatesController,
                          label: 'المستجدات',
                          hint: 'اكتب المستجدات إن وجدت، أو اتركها فارغة لتكتب تلقائياً "لا توجد مستجدات."',
                          maxLines: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // زر توجيه للانتقال للتبويب التالي للمعاينة والتصدير
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'بعد إكمال النموذج، انتقل إلى التبويب الثاني "محرر النص النهائي" لمعاينة المحضر، وتصديره كملف Word ورفعه.',
                              style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Tab 2: محرر النص النهائي ──
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── معلومات الاجتماع ──
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.meeting_room, color: DesktopColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.meeting.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber[200]!),
                                  ),
                                  child: Text(
                                    widget.meeting.status.displayName,
                                    style: TextStyle(color: Colors.amber[900], fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('التاريخ: ${widget.meeting.date}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('الوقت: ${widget.meeting.time}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                            if (widget.meeting.status == MeetingStatus.rejected && widget.meeting.rejectReason != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[100]!),
                                ),
                                child: Text(
                                  'سبب طلب التعديل: ${widget.meeting.rejectReason}',
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── محرر النص النهائي للمحضر ──
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('معاينة وتحرير النص النهائي للمحضر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo')),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'إعادة التوليد من النموذج',
                                  onPressed: () {
                                    _updateCompiledMinutes();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('تمت إعادة توليد المحضر من النموذج.')),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _minutesController,
                              maxLines: 20,
                              minLines: 12,
                              decoration: InputDecoration(
                                hintText: 'اكتب هنا تفاصيل الاجتماع، التوصيات، والقرارات المتخذة...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              style: const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'Courier'),
                            ),
                            const SizedBox(height: 16),

                            // أزرار التصدير والرفع وحفظ المسودة
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _localSaving ? null : _exportDocx,
                                  icon: const Icon(Icons.download),
                                  label: const Text('تصدير كـ Word (.docx)', style: TextStyle(fontFamily: 'Cairo')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DesktopColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _localSaving ? null : _saveDraft,
                                  icon: const Icon(Icons.save),
                                  label: const Text('حفظ كمسودة', style: TextStyle(fontFamily: 'Cairo')),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(_selectedFile != null ? Icons.check_circle : Icons.upload_file,
                                      color: _selectedFile != null ? Colors.green : null),
                                  label: Text(
                                    _selectedFile != null ? 'تغيير الملف المختار' : 'اختر ملف المحضر النهائي',
                                    style: const TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    foregroundColor: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedFile != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[100]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'الملف المختار للرفع: ${_selectedFile!.name}',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // زر التقديم النهائي
                    Consumer<MeetingsViewModel>(
                      builder: (context, vm, child) {
                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: vm.isSaving ? null : _submitForApproval,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DesktopColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: vm.isSaving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'تقديم المحضر للاعتماد (إرسال إلى نائب العميد)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
