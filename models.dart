import 'dart:math';

final _rand = Random();

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rand.nextInt(1 << 30).toRadixString(36);

/// Even number, so `id + 1` is free for a one-off snooze notification.
int newNotificationId() => _rand.nextInt(1 << 30) * 2;

const kLabels = ['Personal', 'Work', 'College', 'Shopping', 'Memory'];

enum Repeat { none, daily, weekly, monthly }

extension RepeatText on Repeat {
  String get label => switch (this) {
        Repeat.none => 'Does not repeat',
        Repeat.daily => 'Every day',
        Repeat.weekly => 'Every week',
        Repeat.monthly => 'Every month',
      };
  String get short => switch (this) {
        Repeat.none => '',
        Repeat.daily => 'daily',
        Repeat.weekly => 'weekly',
        Repeat.monthly => 'monthly',
      };
}

class CheckItem {
  CheckItem({String? id, this.text = '', this.done = false}) : id = id ?? newId();

  final String id;
  String text;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 't': text, 'd': done};

  factory CheckItem.fromJson(Map<String, dynamic> j) => CheckItem(
        id: j['id'] as String?,
        text: (j['t'] as String?) ?? '',
        done: (j['d'] as bool?) ?? false,
      );
}

class Note {
  Note({
    String? id,
    int? nid,
    this.title = '',
    this.body = '',
    this.isList = false,
    List<CheckItem>? items,
    this.color = 0,
    this.label,
    this.pinned = false,
    this.reminder,
    this.repeat = Repeat.none,
    this.archived = false,
    this.trashedAt,
    DateTime? created,
    DateTime? updated,
    this.example = false,
    this.shownFor,
  })  : id = id ?? newId(),
        nid = nid ?? newNotificationId(),
        items = items ?? <CheckItem>[],
        created = created ?? DateTime.now(),
        updated = updated ?? DateTime.now();

  final String id;
  final int nid;
  String title;
  String body;
  bool isList;
  List<CheckItem> items;
  int color;
  String? label;
  bool pinned;
  DateTime? reminder;
  Repeat repeat;
  bool archived;
  DateTime? trashedAt;
  DateTime created;
  DateTime updated;
  bool example;

  /// The reminder time whose big alert has already been shown.
  DateTime? shownFor;

  bool get active => !archived && trashedAt == null;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      items.any((i) => i.text.trim().isNotEmpty);

  bool get isEmpty => !hasContent && reminder == null;

  bool get overdue =>
      reminder != null &&
      repeat == Repeat.none &&
      !reminder!.isAfter(DateTime.now()) &&
      active;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (isList) {
      for (final i in items) {
        if (i.text.trim().isNotEmpty) return i.text.trim();
      }
      return 'Untitled';
    }
    final b = body.trim();
    return b.isEmpty ? 'Untitled' : b.split('\n').first;
  }

  String get searchText =>
      [title, body, label ?? '', ...items.map((i) => i.text)].join(' ').toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'title': title,
        'body': body,
        'list': isList,
        'items': items.map((i) => i.toJson()).toList(),
        'color': color,
        'label': label,
        'pinned': pinned,
        'rem': reminder?.millisecondsSinceEpoch,
        'rep': repeat.index,
        'arch': archived,
        'trash': trashedAt?.millisecondsSinceEpoch,
        'c': created.millisecondsSinceEpoch,
        'u': updated.millisecondsSinceEpoch,
        'ex': example,
        'shown': shownFor?.millisecondsSinceEpoch,
      };

  factory Note.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    final rep = (j['rep'] as num?)?.toInt() ?? 0;
    return Note(
      id: j['id'] as String?,
      nid: (j['nid'] as num?)?.toInt(),
      title: (j['title'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      isList: (j['list'] as bool?) ?? false,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CheckItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      color: (j['color'] as num?)?.toInt() ?? 0,
      label: j['label'] as String?,
      pinned: (j['pinned'] as bool?) ?? false,
      reminder: d(j['rem']),
      repeat: Repeat.values[(rep >= 0 && rep < Repeat.values.length) ? rep : 0],
      archived: (j['arch'] as bool?) ?? false,
      trashedAt: d(j['trash']),
      created: d(j['c']),
      updated: d(j['u']),
      example: (j['ex'] as bool?) ?? false,
      shownFor: d(j['shown']),
    );
  }
}

/// Next occurrence of a repeating reminder that is after now.
DateTime nextRepeat(DateTime from, Repeat r) {
  if (r == Repeat.none) return from;
  final now = DateTime.now();
  var d = from;
  var guard = 0;
  while (!d.isAfter(now) && guard++ < 5000) {
    d = switch (r) {
      Repeat.daily => DateTime(d.year, d.month, d.day + 1, d.hour, d.minute),
      Repeat.weekly => DateTime(d.year, d.month, d.day + 7, d.hour, d.minute),
      Repeat.monthly => DateTime(d.year, d.month + 1, d.day, d.hour, d.minute),
      Repeat.none => d,
    };
  }
  return d;
}
