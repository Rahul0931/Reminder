const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A time [dayOffset] days from today at [h]:[m].
DateTime atDay(int dayOffset, int h, [int m = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + dayOffset, h, m);
}

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

String fmtWhen(DateTime d) {
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = (day.difference(today).inHours / 24).round();
  final String label;
  if (diff == 0) {
    label = 'Today';
  } else if (diff == 1) {
    label = 'Tomorrow';
  } else if (diff == -1) {
    label = 'Yesterday';
  } else if (diff > 1 && diff < 7) {
    label = _wd[d.weekday - 1];
  } else {
    label = '${d.day} ${_mo[d.month - 1]}';
  }
  return '$label, ${fmtTime(d)}';
}

String ago(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '$m min ago';
  final h = (m / 60).round();
  if (h < 24) return '$h h ago';
  return '${(h / 24).round()} d ago';
}

/// One-tap reminder times shown in the editor.
final Map<String, DateTime Function()> kQuickTimes = {
  'In 1 hour': () => DateTime.now().add(const Duration(hours: 1)),
  'Tonight 8 PM': () {
    final t = atDay(0, 20);
    return t.isAfter(DateTime.now()) ? t : atDay(1, 20);
  },
  'Tomorrow 9 AM': () => atDay(1, 9),
  'Next Monday': () {
    final w = DateTime.now().weekday; // Mon = 1 … Sun = 7
    final add = (8 - w) % 7 == 0 ? 7 : (8 - w) % 7;
    return atDay(add, 9);
  },
  'Weekend': () {
    final w = DateTime.now().weekday;
    var add = (6 - w + 7) % 7;
    if (add == 0 && DateTime.now().isAfter(atDay(0, 10))) add = 7;
    return atDay(add, 10);
  },
};
