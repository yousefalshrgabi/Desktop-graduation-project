import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import 'package:academic_affairs_management/features/mobile_pages/meetings/meeting_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CollegesMeetingsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _colleges = [];
  List<MeetingModel> _meetings = [];
  Map<String, String> _departmentNames = {};
  bool _isLoading = false;
  String _errorMessage = '';

  String _searchQuery = '';
  String? _selectedCollege;

  List<MeetingModel> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String? get selectedCollege => _selectedCollege;

  Map<String, String> get departmentNames => _departmentNames;
  List<Map<String, dynamic>> get colleges => _colleges;

  List<String> get collegesList {
    final list = _meetings.map((m) => m.college).where((c) => c.isNotEmpty).toSet().toList();
    list.sort();
    return list;
  }

  List<MeetingModel> get filteredMeetings {
    return _meetings.where((meeting) {
      // 1. Search text
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = meeting.title.toLowerCase();
        final deptName = (_departmentNames[meeting.departmentId] ?? '').toLowerCase();
        final deptId = meeting.departmentId.toLowerCase();
        if (!title.contains(query) && !deptName.contains(query) && !deptId.contains(query)) {
          return false;
        }
      }
      // 2. College filter
      if (_selectedCollege != null && _selectedCollege!.isNotEmpty) {
        if (meeting.college != _selectedCollege) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Load department name mapping from SQLite
      final db = await DatabaseHelper.instance.database;
      final deptRes = await db.query('departments', columns: ['id', 'name']);
      final Map<String, String> tempDepts = {};
      for (final row in deptRes) {
        tempDepts[row['id'].toString()] = row['name'].toString();
      }
      _departmentNames = tempDepts;

      // 2. Load meetings from Firestore
      final snapshot = await _firestore
          .collection('meetings')
          .orderBy('createdAt', descending: true)
          .get();

      _meetings = snapshot.docs
          .map((doc) => MeetingModel.fromMap(doc.data()))
          .where((m) => m.status == MeetingStatus.forwardedToPresidency)
          .toList();

      // 3. Load all colleges from SQLite for the filter
      final collegesRes = await db.query('colleges', columns: ['ar_name']);
      final Set<String> uniqueColleges = collegesRes
          .map((row) => row['ar_name'].toString())
          .where((name) => name.isNotEmpty)
          .toSet();

      // Add colleges from meetings as well just in case they are not in the SQLite table
      for (final meeting in _meetings) {
        if (meeting.college.isNotEmpty) {
          uniqueColleges.add(meeting.college);
        }
      }

      final list = uniqueColleges.toList();
      list.sort();
      _colleges = list.map((name) => {
        'id': name,
        'name': name,
      }).toList();
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateSelectedCollege(String? college) {
    _selectedCollege = college;
    notifyListeners();
  }
}
