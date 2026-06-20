import 'package:uuid/uuid.dart';
import 'package:academic_affairs_management/core/DB/DatabaseHelper.dart';
import '../models/graduation_project_group.dart';

class GraduationProjectLocalService {
  static const String _tableName = 'graduation_projects';
  final _uuid = const Uuid();

  Future<List<GraduationProjectGroup>> getGroupsForTeacher(String teacherName) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      _tableName,
      where: 'teacher_name = ?',
      whereArgs: [teacherName],
    );

    return maps.map((data) => _mapToGroup(data)).toList();
  }

  Future<List<GraduationProjectGroup>> getAllGroups() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(_tableName);

    return maps.map((data) => _mapToGroup(data)).toList();
  }

  Future<void> saveGroup(GraduationProjectGroup group) async {
    final db = await DatabaseHelper.instance.database;
    final isNew = group.id.isEmpty;
    final id = isNew ? _uuid.v4() : group.id;

    final data = {
      'id': id,
      'teacher_name': group.teacherName,
      'group_number': group.groupNumber,
      'student_count': group.studentCount,
      'schedule_type': group.scheduleType,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (isNew) {
      await db.insert(_tableName, data);
    } else {
      await db.update(
        _tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> deleteAllGroupsForTeacher(String teacherName) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      _tableName,
      where: 'teacher_name = ?',
      whereArgs: [teacherName],
    );
  }

  Future<int> getNextGroupNumber(String teacherName) async {
    final groups = await getGroupsForTeacher(teacherName);
    if (groups.isEmpty) return 1;
    return groups.map((g) => g.groupNumber).reduce((a, b) => a > b ? a : b) + 1;
  }

  GraduationProjectGroup _mapToGroup(Map<String, dynamic> data) {
    return GraduationProjectGroup.fromMap(
      data['id'] as String,
      {
        'teacherName': data['teacher_name'],
        'groupNumber': data['group_number'],
        'studentCount': data['student_count'],
        'scheduleType': data['schedule_type'],
      },
    );
  }
}
