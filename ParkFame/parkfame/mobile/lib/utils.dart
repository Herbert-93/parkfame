import 'package:intl/intl.dart';

final _n = NumberFormat('#,##0');
String ugx(num v) => 'UGX ${_n.format(v.round())}';

String durationText(int minutes) {
  final d = minutes ~/ 1440, h = (minutes % 1440) ~/ 60, m = minutes % 60;
  return [if (d > 0) '${d}d', if (h > 0) '${h}h', '${m}m'].join(' ');
}

String timeText(DateTime t) => DateFormat('d MMM, h:mm a').format(t);
bool isToday(DateTime t) {
  final n = DateTime.now();
  return t.year == n.year && t.month == n.month && t.day == n.day;
}
