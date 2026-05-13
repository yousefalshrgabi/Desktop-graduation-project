import 'package:academic_affairs_management/features/desktop_pages/colleges_screen/college_model.dart';
import 'package:academic_affairs_management/features/desktop_pages/faculty_members_screen/faculty_member_model.dart';

class DashboardStats {
  final int totalColleges;
  final int totalFacultyMembers;
  final int totalUsers;
  final int totalPrograms;
  final int totalStudyPlans;
  final List<CollegeModel> recentColleges;
  final List<FacultyMemberModel> recentFaculty;

  DashboardStats({
    this.totalColleges = 0,
    this.totalFacultyMembers = 0,
    this.totalUsers = 0,
    this.totalPrograms = 0,
    this.totalStudyPlans = 0,
    this.recentColleges = const [],
    this.recentFaculty = const [],
  });

  DashboardStats copyWith({
    int? totalColleges,
    int? totalFacultyMembers,
    int? totalUsers,
    int? totalPrograms,
    int? totalStudyPlans,
    List<CollegeModel>? recentColleges,
    List<FacultyMemberModel>? recentFaculty,
  }) {
    return DashboardStats(
      totalColleges: totalColleges ?? this.totalColleges,
      totalFacultyMembers: totalFacultyMembers ?? this.totalFacultyMembers,
      totalUsers: totalUsers ?? this.totalUsers,
      totalPrograms: totalPrograms ?? this.totalPrograms,
      totalStudyPlans: totalStudyPlans ?? this.totalStudyPlans,
      recentColleges: recentColleges ?? this.recentColleges,
      recentFaculty: recentFaculty ?? this.recentFaculty,
    );
  }
}
