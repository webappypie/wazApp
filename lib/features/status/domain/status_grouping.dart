// lib/features/status/domain/status_grouping.dart
//
// Grouping of status files. WHY BY DAY AND NOT BY CONTACT: the status folder only contains files
// named by a content hash (32 hex characters) with no contact, EXIF or sidecar metadata, and the
// only place WhatsApp stores the sender is its private (encrypted) database, which WazApp must not
// read. Grouping by contact would therefore be invented, so statuses are grouped by what the data
// really supports: the day the file became available in the folder.

import 'status_models.dart';
import '../../library/domain/library_models.dart';

class StatusDayGroup {
  const StatusDayGroup(this.label, this.day, this.items);

  /// "Today", "Yesterday" or a date such as "21 Oct".
  final String label;
  final DateTime day;
  final List<StatusItem> items;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String dayLabel(DateTime day, DateTime now) {
  final today = _dayOf(now);
  final diff = today.difference(_dayOf(day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${day.day} ${_months[day.month - 1]}';
  return day.year == now.year ? base : '$base ${day.year}';
}

/// Newest day first; inside a day, newest item first. Optionally keeps only one media kind.
List<StatusDayGroup> groupStatusesByDay(Iterable<StatusItem> items, DateTime now, {MediaKind? kind}) {
  final byDay = <DateTime, List<StatusItem>>{};
  for (final i in items) {
    if (kind != null && i.kind != kind) continue;
    byDay.putIfAbsent(_dayOf(i.modified), () => []).add(i);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      StatusDayGroup(
        dayLabel(d, now),
        d,
        byDay[d]!..sort((a, b) => b.modified.compareTo(a.modified)),
      ),
  ];
}
