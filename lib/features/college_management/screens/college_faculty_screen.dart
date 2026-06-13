import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/core/services/app_session.dart';
import 'package:academic_affairs_management/features/college_management/screens/mobile_faculty_edit_screen.dart';
import 'package:academic_affairs_management/features/college_management/screens/mobile_faculty_profile_screen.dart';
import 'package:flutter/material.dart';

class CollegeFacultyScreen extends StatefulWidget {
  const CollegeFacultyScreen({super.key});

  @override
  State<CollegeFacultyScreen> createState() => _CollegeFacultyScreenState();
}

class _CollegeFacultyScreenState extends State<CollegeFacultyScreen> {
  late final String _collegeName;
  List<Map<String, dynamic>> _facultyMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _collegeName = AppSession().userCollege;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // جلب أعضاء هيئة التدريس التابعين للكلية الحالية عبر ربط جدول الدكاترة مع جدول المستخدمين
      _facultyMembers = await db.rawQuery('''
        SELECT f.*, u.department as user_dept 
        FROM faculty_members f 
        JOIN users u ON f.user_id = u.id 
        WHERE u.faculty = ?
      ''', [_collegeName]);

    } catch (e) {
      debugPrint('Error loading faculty members: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEditScreen(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFacultyEditScreen(facultyData: data),
      ),
    );
  }

  void _viewMemberDetails(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFacultyProfileScreen(facultyData: data),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_collegeName.isEmpty || _collegeName == 'غير محدد') {
      return Scaffold(
        appBar: AppBar(title: const Text('أعضاء هيئة التدريس بالكلية')),
        body: const Center(
          child: Text('عذراً، لم يتم تحديد كلية لحسابك.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('أعضاء الكلية: $_collegeName'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _facultyMembers.isEmpty
              ? const Center(child: Text('لا يوجد أعضاء هيئة تدريس مسجلين في هذه الكلية.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _facultyMembers.length,
                  itemBuilder: (context, index) {
                    final data = _facultyMembers[index];
                    final name = data['name']?.toString() ?? 'بدون اسم';
                    final department = data['department']?.toString() ?? data['user_dept']?.toString() ?? 'غير محدد';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0] : '؟',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('القسم: ${department.isEmpty ? 'غير محدد' : department}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded),
                              color: Theme.of(context).colorScheme.primary,
                              tooltip: 'التفاصيل',
                              onPressed: () => _viewMemberDetails(data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded),
                              color: Colors.orange,
                              tooltip: 'تحديث البيانات',
                              onPressed: () => _navigateToEditScreen(data),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
