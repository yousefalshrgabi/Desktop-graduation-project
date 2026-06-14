import 'fet_day_mapping.dart';

/// Sorting and layout helpers for day × hour grids.
class TimetableScheduleGrid {
  TimetableScheduleGrid._();

  static int compareHours(String a, String b) {
    final na = int.tryParse(a.trim());
    final nb = int.tryParse(b.trim());
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null && nb == null) return -1;
    if (na == null && nb != null) return 1;
    return a.compareTo(b);
  }

  static List<String> sortedDays(Iterable<String> days) {
    const order = kArabicWeekdayOrder;
    final list = days.toSet().toList();
    list.sort((a, b) {
      final ia = order.indexOf(a);
      final ib = order.indexOf(b);
      if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
      if (ia >= 0) return -1;
      if (ib >= 0) return 1;
      return a.compareTo(b);
    });
    return list;
  }

  static List<String> sortedHours(Iterable<String> hours) {
    final list = hours.toSet().toList()..sort(compareHours);
    return list;
  }
}
