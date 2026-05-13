import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/theme/desktop_theme.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/desktop_pages/SyncDialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faculty_members_view_model.dart';
import 'add_faculty_member_dialog.dart';

class FacultyMembers extends StatefulWidget {
  const FacultyMembers({super.key});

  @override
  State<FacultyMembers> createState() => _FacultyMembersState();
}

class _FacultyMembersState extends State<FacultyMembers> {
  final FacultyMembersViewModel _viewModel = FacultyMembersViewModel();
  final TextEditingController _searchController = TextEditingController();

  // 🌟 متغيرات الفلترة
  String _searchQuery = '';
  String? _selectedFaculty;
  String? _selectedDepartment;
  String? _selectedDegree;
  String? _selectedStatus;

  // 🌟 متغيرات قواعد البيانات المساعدة للفلترة
  List<Map<String, dynamic>> _dbColleges = [];
  List<Map<String, dynamic>> _dbDepartments = [];
  Map<String, String> _userFaculties =
      {}; // لربط الدكتور بكليته من جدول المستخدمين

  bool _wasLoading = false;

  @override
  void initState() {
    super.initState();
    _viewModel.fetchFacultyMembers();
    _loadDynamicFiltersData();

    // تحديث المرشحات تلقائياً بعد أي استيراد أو تغيير
    _viewModel.addListener(() {
      if (_wasLoading && !_viewModel.isLoading) {
        _loadDynamicFiltersData();
      }
      _wasLoading = _viewModel.isLoading;
    });
  }

  // 🌟 جلب الكليات والأقسام من الجداول لتهيئتها في المرشحات
  Future<void> _loadDynamicFiltersData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final colleges = await db.query('colleges');
      final departments = await db.query('departments');

      // سحب كليات المستخدمين لربط الدكتور بكليته (لأن الكلية محفوظة في جدول users)
      final users = await db.query('users', columns: ['id', 'faculty']);
      Map<String, String> tempUserFaculties = {};
      for (var u in users) {
        tempUserFaculties[u['id'].toString()] = u['faculty']?.toString() ?? '';
      }

      if (mounted) {
        setState(() {
          _dbColleges = colleges;
          _dbDepartments = departments;
          _userFaculties = tempUserFaculties;
        });
      }
    } catch (e) {
      debugPrint('Error loading dynamic filter data: $e');
    }
  }

  Future<void> _openLocalFile(BuildContext context, String path, String url, String memberName) async {
    String actualPath = path;

    // إذا كان المسار المحلي فارغاً ولكن يوجد رابط، ننشئ مساراً جديداً للحفظ
    if (actualPath.isEmpty && url.isNotEmpty) {
      String cleanName = memberName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      Directory appDocDir = await getApplicationDocumentsDirectory();
      
      Uri parsedUrl = Uri.parse(url);
      String ext = '.pdf';
      // محاولة استخراج الامتداد من الرابط
      if (parsedUrl.path.contains('.')) {
        String possibleExt = parsedUrl.path.split('.').last;
        if (possibleExt.length <= 4) ext = '.$possibleExt';
      }
      String fileName = 'document_${DateTime.now().millisecondsSinceEpoch}$ext';
      
      actualPath = p.join(appDocDir.path, 'AcademicAffairs', 'FacultyFiles', cleanName, fileName);
    }

    if (actualPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الملف، المسار غير متوفر')),
        );
      }
      return;
    }

    final File file = File(actualPath);
    if (await file.exists()) {
      final Uri uri = Uri.file(path);
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الملف في المسار: $path')),
          );
        }
      }
    } else {
      if (url.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('جاري تحميل الملف من السحابة...'),
              ],
            ),
          ),
        );

        try {
          final dir = file.parent;
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          
          // استخدام HttpClient للتحميل المباشر والموثوق
          final request = await HttpClient().getUrl(Uri.parse(url));
          final response = await request.close();
          
          if (response.statusCode == 200) {
            await response.pipe(file.openWrite());
          } else {
            throw Exception('فشل التحميل، كود الخطأ: ${response.statusCode}');
          }

          if (context.mounted) {
            Navigator.pop(context); // إغلاق مربع التحميل
          }

          final Uri uri = Uri.file(actualPath);
          if (!await launchUrl(uri)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر فتح الملف بعد التحميل: $actualPath')),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل تحميل الملف: $e')),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الملف غير موجود محلياً ولا يوجد رابط سحابي له.')),
          );
        }
      }
    }
  }

  // ==================== استخراج القوائم الديناميكية للمرشحات ====================

  // 1. قائمة الكليات (من جدول colleges)
  List<String> get _availableFaculties {
    return _dbColleges.map((c) => c['ar_name'].toString()).toSet().toList()
      ..sort();
  }

  // 2. قائمة الأقسام (تتغير بناءً على الكلية المختارة)
  List<String> get _availableDepartments {
    if (_selectedFaculty != null) {
      // إذا اختار كلية، نبحث عن المعرف الخاص بها
      final college = _dbColleges.firstWhere(
        (c) => c['ar_name'].toString() == _selectedFaculty,
        orElse: () => {},
      );

      if (college.isNotEmpty) {
        // نعرض فقط الأقسام التي تتبع لهذه الكلية
        final collegeId = college['id'];
        return _dbDepartments
            .where((d) => d['college_id'] == collegeId)
            .map((d) => d['name'].toString())
            .toSet()
            .toList()
          ..sort();
      }
      return [];
    } else {
      // إذا لم يحدد كلية، نعرض جميع الأقسام من جدول الأقسام
      return _dbDepartments.map((d) => d['name'].toString()).toSet().toList()
        ..sort();
    }
  }

  // 3. الدرجات العلمية (من الأعضاء الموجودين)
  List<String> get _dynamicDegrees {
    return _viewModel.allMembers
        .map((m) => m.currentAcademicTitle)
        .where((d) => d.isNotEmpty && d != 'غير محدد')
        .toSet()
        .toList()
      ..sort();
  }

  // 4. الحالات (من الأعضاء الموجودين)
  List<String> get _dynamicStatuses {
    return _viewModel.allMembers
        .map((m) => m.status)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // ========================================================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesktopColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesktopSpacing.md),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: DesktopSpacing.lg),
            _buildFiltersAndActions(context),
            const SizedBox(height: DesktopSpacing.md),
            _buildFacultyMembersTableLocal(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.school, color: DesktopColors.primary),
          const SizedBox(width: DesktopSpacing.xs),
          Text('نظام الشؤون الأكاديمية',
              style:
                  DesktopTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () {}, child: const Text('العربية | EN')),
        IconButton(
          tooltip: 'مزامنة السحابة',
          icon: const Icon(Icons.cloud_sync_outlined,
              color: DesktopColors.primary),
          onPressed: () {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => SyncDialog());
          },
        ),
        IconButton(
            icon: const Icon(Icons.notifications_none), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
              backgroundColor: Color.fromARGB(255, 219, 215, 220),
              child: Text('أ')),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة أعضاء هيئة التدريس',
                style: DesktopTextStyles.heading1),
            const SizedBox(height: DesktopSpacing.xs / 2),
            Text('إضافة وتعديل وحذف أعضاء هيئة التدريس في الأقسام الأكاديمية',
                style: DesktopTextStyles.caption),
            const SizedBox(height: DesktopSpacing.xs),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersAndActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم، الرقم الوظيفي، أو التخصص...',
                  prefixIcon: const Icon(Icons.search),
                  enabledBorder:
                      DesktopInputTheme.inputDecorationTheme.enabledBorder,
                  focusedBorder:
                      DesktopInputTheme.inputDecorationTheme.focusedBorder,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: DesktopSpacing.xs),
            ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  return ElevatedButton.icon(
                    onPressed: _viewModel.isLoading
                        ? null
                        : () =>
                            _viewModel.importFacultyMembersFromExcel(context),
                    icon: _viewModel.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text('استيراد الإكسل',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: DesktopSpacing.md, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }),
            const SizedBox(width: DesktopSpacing.xs),
            ElevatedButton(
              onPressed: () {
                showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        AddFacultyMemberDialog(viewModel: _viewModel));
              },
              style: DesktopButtonTheme.elevatedButtonTheme.style,
              child: const Row(children: [
                Icon(Icons.add, color: DesktopColors.surface),
                SizedBox(width: 8),
                Text('إضافة عضو جديد')
              ]),
            )
          ],
        ),
        const SizedBox(height: DesktopSpacing.sm),

        // 🌟 صف المرشحات الديناميكية
        Row(
          children: [
            _buildDropdownFilter(
                'كل الكليات', _selectedFaculty, _availableFaculties, (val) {
              setState(() {
                _selectedFaculty = val;
                _selectedDepartment =
                    null; // 👈 تصفير القسم إجبارياً عند تغيير الكلية
              });
            }),
            const SizedBox(width: 10),
            _buildDropdownFilter(
                'كل الأقسام', _selectedDepartment, _availableDepartments,
                (val) {
              setState(() => _selectedDepartment = val);
            }),
            const SizedBox(width: 10),
            _buildDropdownFilter(
                'اللقب العلمي',
                _selectedDegree,
                _dynamicDegrees,
                (val) => setState(() => _selectedDegree = val)),
            const SizedBox(width: 10),
            _buildDropdownFilter('الحالة', _selectedStatus, _dynamicStatuses,
                (val) => setState(() => _selectedStatus = val)),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedFaculty = null;
                  _selectedDepartment = null;
                  _selectedDegree = null;
                  _selectedStatus = null;
                });
              },
              child: const Text('مسح المرشحات',
                  style: TextStyle(color: DesktopColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(String label, String? selectedValue,
      List<String> items, void Function(String?) onChanged) {
    String? safeValue = selectedValue;
    if (safeValue != null && !items.contains(safeValue)) safeValue = null;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DesktopSpacing.xs + 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DesktopColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Text(label, style: DesktopTextStyles.caption),
            value: safeValue,
            isExpanded: true,
            items: items
                .map((e) => DropdownMenuItem(
                    value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyMembersTableLocal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesktopColors.border),
      ),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(DesktopSpacing.lg),
                    child: CircularProgressIndicator()));
          }

          if (_viewModel.errorMessage.isNotEmpty) {
            return Center(child: Text('حدث خطأ: ${_viewModel.errorMessage}'));
          }

          if (_viewModel.allMembers.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(DesktopSpacing.lg),
                    child: Text('لا يوجد أعضاء هيئة تدريس مسجلين حالياً')));
          }

          // 🌟 تطبيق منطق الفلترة المتقدم
          final members = _viewModel.allMembers.where((m) {
            // 1. البحث النصي
            final matchesSearch = _searchQuery.isEmpty ||
                m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                m.jobNumber.contains(_searchQuery) ||
                m.generalSpecialization
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());

            // 2. فلتر الكلية (يعرض كل أعضاء الكلية)
            final memberFaculty = _userFaculties[m.userId] ?? '';
            final matchesFaculty =
                _selectedFaculty == null || memberFaculty == _selectedFaculty;

            // 3. فلتر القسم (مبني على القسم المختار - اختياري)
            final matchesDept = _selectedDepartment == null ||
                m.department == _selectedDepartment;

            // 4. فلتر اللقب العلمي
            final matchesDegree = _selectedDegree == null ||
                m.currentAcademicTitle == _selectedDegree;

            // 5. فلتر الحالة
            final matchesStatus =
                _selectedStatus == null || m.status == _selectedStatus;

            return matchesSearch &&
                matchesFaculty &&
                matchesDept &&
                matchesDegree &&
                matchesStatus;
          }).toList();

          if (members.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(DesktopSpacing.lg),
                    child: Text('لا توجد نتائج تطابق المرشحات الحالية.')));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomDataTable(
                columns: const [
                  DataColumn(
                      label: Text('الالرقم الوظيفي',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الاسم', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('القسم', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('اللقب العلمي',
                          style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('الحالة', style: DesktopTextStyles.caption)),
                  DataColumn(
                      label: Text('إجراءات', style: DesktopTextStyles.caption)),
                ],
                rows: members.map((member) {
                  return DataRow(cells: [
                    DataCell(Text(
                        member.jobNumber.isNotEmpty ? member.jobNumber : '---',
                        style: DesktopTextStyles.caption)),
                    DataCell(Text(member.name, style: DesktopTextStyles.body)),
                    DataCell(
                        Text(member.department, style: DesktopTextStyles.body)),
                    DataCell(Text(member.currentAcademicTitle,
                        style: DesktopTextStyles.body)),
                    DataCell(_buildStatusBadge(member.status)),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AddFacultyMemberDialog(
                                viewModel: _viewModel,
                                memberToEdit: member,
                              ),
                            );
                          } else if (value == 'view_file') {
                            if (member.localFilePath.isNotEmpty || member.fileUrl.isNotEmpty) {
                              List<String> paths = [];
                              if (member.localFilePath.isNotEmpty) {
                                if (member.localFilePath.startsWith('[')) {
                                  try {
                                    paths = List<String>.from(jsonDecode(member.localFilePath));
                                  } catch (e) {
                                    paths = [member.localFilePath];
                                  }
                                } else {
                                  paths = [member.localFilePath];
                                }
                              }

                              List<String> urls = [];
                              if (member.fileUrl.isNotEmpty) {
                                if (member.fileUrl.startsWith('[')) {
                                  try {
                                    urls = List<String>.from(jsonDecode(member.fileUrl));
                                  } catch (e) {
                                    urls = [member.fileUrl];
                                  }
                                } else {
                                  urls = [member.fileUrl];
                                }
                              }

                              int count = paths.length > urls.length ? paths.length : urls.length;

                              if (count == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('لا يوجد ملف مرفق لهذا العضو')),
                                );
                              } else if (count == 1) {
                                String p = paths.isNotEmpty ? paths[0] : '';
                                String u = urls.isNotEmpty ? urls[0] : '';
                                await _openLocalFile(context, p, u, member.name);
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('اختيار الملف المرفق'),
                                    content: SizedBox(
                                      width: 400,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: count,
                                        itemBuilder: (c, i) {
                                          String p = i < paths.length ? paths[i] : '';
                                          String u = i < urls.length ? urls[i] : '';
                                          String fileName = p.isNotEmpty 
                                              ? p.split(RegExp(r'[\\/]')).last 
                                              : 'ملف ${i + 1} من السحابة';
                                              
                                          return ListTile(
                                            leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                                            title: Text(fileName),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _openLocalFile(context, p, u, member.name);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('إغلاق'),
                                      )
                                    ],
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('لا يوجد ملف مرفق لهذا العضو')),
                              );
                            }
                          } else if (value == 'delete') {
                            _viewModel.deleteFacultyMember(member.id);
                          }
                        },
                        itemBuilder: (context) => [
                          // 🌟 إضافة خيار "عرض الملف" في القائمة المنسدلة 🌟
                          const PopupMenuItem(
                            value: 'view_file',
                            child: Row(children: [
                              Icon(Icons.description,
                                  color: Colors.purple, size: 16),
                              SizedBox(width: 8),
                              Text('عرض الملف المرفق',
                                  style: TextStyle(color: Colors.purple))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text('تعديل',
                                  style: TextStyle(color: Colors.blue))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.red))
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'نشط':
      case 'متفرغ':
        color = Colors.green;
        break;
      case 'غير نشط':
      case 'منتدب':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DesktopSpacing.xs, vertical: DesktopSpacing.xs / 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class CustomDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CustomDataTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: DesktopColors.border,
        dataTableTheme: DataTableThemeData(
          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
        ),
      ),
      child: DataTable(
        columns: columns,
        rows: rows,
        columnSpacing: DesktopSpacing.md,
        horizontalMargin: DesktopSpacing.md,
      ),
    );
  }
}
