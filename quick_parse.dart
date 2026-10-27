import 'format.dart';

class Parsed {
  const Parsed(this.title, this.when);
  final String title;
  final DateTime? when;
}

const _weekdays = {'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7};

/// Turns "call mom tomorrow 6pm" into title "Call mom" + a reminder time.
Parsed parseQuick(String input) {
  var t = ' $input ';
  final now = DateTime.now();
  DateTime? when;
  RegExpMatch? m;

  m = RegExp(r'\s(?:in|after)\s+(\d+)\s*(minutes|minute|mins|min|m|hours|hour|hrs|hr|h|days|day|d)\b',
          caseSensitive: false)
      .firstMatch(t);
  if (m != null) {
    final n = int.parse(m.group(1)!);
    final u = m.group(2)!.toLowerCase()[0];
    when = now.add(u == 'm'
        ? Duration(minutes: n)
        : u == 'h'
            ? Duration(hours: n)
            : Duration(days: n));
    t = t.replaceFirst(m.group(0)!, ' ');
  } else {
    int? day;
    var tonight = false;
    int? hh;
    var mm = 0;

    m = RegExp(r'\s(today|tonight|tomorrow|tmrw|tmr|kal)\b', caseSensitive: false).firstMatch(t);
    if (m != null) {
      final w = m.group(1)!.toLowerCase();
      day = (w == 'today' || w == 'tonight') ? 0 : 1;
      tonight = w == 'tonight';
      t = t.replaceFirst(m.group(0)!, ' ');
    } else {
      m = RegExp(
              r'\s(?:on\s+|next\s+|this\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|tues|wed|thu|thurs|fri|sat)\b',
              caseSensitive: false)
          .firstMatch(t);
      if (m != null) {
        final target = _weekdays[m.group(1)!.toLowerCase().substring(0, 3)]!;
        var add = (target - now.weekday + 7) % 7;
        if (add == 0) add = 7;
        day = add;
        t = t.replaceFirst(m.group(0)!, ' ');
      }
    }

    m = RegExp(r'\s(?:at\s+|@\s*)?(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b', caseSensitive: false)
        .firstMatch(t);
    if (m != null) {
      hh = int.parse(m.group(1)!) % 12 + (m.group(3)!.toLowerCase() == 'pm' ? 12 : 0);
      mm = int.tryParse(m.group(2) ?? '') ?? 0;
      t = t.replaceFirst(m.group(0)!, ' ');
    } else {
      m = RegExp(r'\s(?:at\s+)?([01]?\d|2[0-3])[:.]([0-5]\d)\b', caseSensitive: false).firstMatch(t);
      if (m != null) {
        hh = int.parse(m.group(1)!);
        mm = int.parse(m.group(2)!);
        t = t.replaceFirst(m.group(0)!, ' ');
      } else {
        m = RegExp(r'\sat\s+(\d{1,2})\b', caseSensitive: false).firstMatch(t);
        if (m != null) {
          hh = int.parse(m.group(1)!);
          if (hh < 8) hh += 12;
          t = t.replaceFirst(m.group(0)!, ' ');
        }
      }
    }

    if (hh != null && hh < 24) {
      final d = day ?? (atDay(0, hh, mm).isAfter(now) ? 0 : 1);
      when = atDay(d, hh, mm);
    } else if (day != null) {
      var w = tonight ? atDay(0, 20) : atDay(day, 9);
      if (!w.isAfter(now)) w = now.add(const Duration(hours: 1));
      when = w;
    }
  }

  var title = t
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceFirst(RegExp(r'\s+(at|on|by)\s*$', caseSensitive: false), '')
      .trim();
  if (title.isEmpty) title = input.trim();
  if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);
  return Parsed(title, when);
}
