class LeaveRequestModel {
  final String leaveType;
  final int duration;
  final DateTime startDate;
  final String senderDepartment;

  LeaveRequestModel({
    required this.leaveType,
    required this.duration,
    required this.startDate,
    required this.senderDepartment,
  });
}
