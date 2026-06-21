import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'college_faculty_view_model.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_faculty_edit/mobile_faculty_edit_view.dart';
import 'package:academic_affairs_management/features/mobile_pages/mobile_faculty_profile/mobile_faculty_profile_view.dart';

class CollegeFacultyView extends StatefulWidget {
  const CollegeFacultyView({super.key});

  @override
  State<CollegeFacultyView> createState() => _CollegeFacultyViewState();
}

class _CollegeFacultyViewState extends State<CollegeFacultyView> {
  late final CollegeFacultyViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CollegeFacultyViewModel();
    _viewModel.loadData();
  }

  void _navigateToEditScreen(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFacultyEditView(facultyData: data),
      ),
    ).then((_) => _viewModel.loadData());
  }

  void _viewMemberDetails(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobileFacultyProfileView(facultyData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CollegeFacultyViewModel>.value(
      value: _viewModel,
      child: Consumer<CollegeFacultyViewModel>(
        builder: (context, viewModel, child) {
          final collegeName = viewModel.collegeName;

          if (collegeName.isEmpty || collegeName == 'غير محدد') {
            return Scaffold(
              appBar: AppBar(title: const Text('أعضاء هيئة التدريس بالكلية')),
              body: const Center(
                child: Text('عذراً، لم يتم تحديد كلية لحسابك.'),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text('أعضاء الكلية: $collegeName'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: viewModel.loadData,
                ),
              ],
            ),
            body: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : viewModel.facultyMembers.isEmpty
                    ? const Center(child: Text('لا يوجد أعضاء هيئة تدريس مسجلين في هذه الكلية.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.facultyMembers.length,
                        itemBuilder: (context, index) {
                          final data = viewModel.facultyMembers[index];
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
        },
      ),
    );
  }
}
