import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import 'note_card.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.store, required this.noteId});

  final NoteStore store;
  final String noteId;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  NoteStore get store => widget.store;
  late final Note n;
  late final TextEditingController titleCtrl;
  late final TextEditingController bodyCtrl;
  final addCtrl = TextEditingController();
  final addFocus = FocusNode();
  final titleFocus = FocusNode();
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focus = {};

  @override
  void initState() {
    super.initState();
    n = store.byId(widget.noteId)!;
    titleCtrl = TextEditingController(text: n.title);
    bodyCtrl = TextEditingController(text: n.body);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!n.hasContent && n.title.trim().isEmpty) {
        titleFocus.requestFocus();
      } else if (n.isList && n.items.isEmpty) {
        addFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    addCtrl.dispose();
    addFocus.dispose();
    titleFocus.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(CheckItem it) =>
      _ctrls.putIfAbsent(it.id, () => TextEditingController(text: it.text));
  FocusNode _f(CheckItem it) => _focus.putIfAbsent(it.id, () => FocusNode());

  void _changed({bool reminder = false}) {
    store.changed(n, reminder: reminder);
  }

  void _toast(String m) {
    final s = ScaffoldMessenger.of(context);
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  void _setMode(bool list) {
    if (list == n.isList) return;
    if (list) {
      n.items = n.body
          .split('\n')
          .map((s) => s.replaceFirst(RegExp(r'^\s*[-*•]\s*'), '').trim())
          .where((s) => s.isNotEmpty)
          .map((s) => CheckItem(text: s))
          .toList();
      n.body = '';
      bodyCtrl.text = '';
    } else {
      n.body = n.items.map((i) => i.text).join('\n');
      bodyCtrl.text = n.body;
      n.items = [];
    }
    n.isList = list;
    _changed();
    if (list) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) addFocus.requestFocus();
      });
    }
  }

  CheckItem _insertAfter(CheckItem? after, String text) {
    final it = CheckItem(text: text);
    final idx = after == null ? n.items.length : n.items.indexOf(after) + 1;
    n.items.insert(idx, it);
    _changed();
    return it;
  }

  void _newItemAfter(CheckItem after) {
    final it = _insertAfter(after, '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _f(it).requestFocus();
    });
  }

  void _forget(CheckItem it) {
    final c = _ctrls.remove(it.id);
    final f = _focus.remove(it.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c?.dispose();
      f?.dispose();
    });
  }

  void _removeItem(CheckItem it) {
    n.items.remove(it);
    _forget(it);
    _changed();
  }

  void _removeTicked() {
    for (final it in n.items.where((i) => i.done).toList()) {
      n.items.remove(it);
      _forget(it);
    }
    _changed();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    var init = n.reminder ?? now.add(const Duration(hours: 1));
    if (init.isBefore(now)) init = now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null || !mounted) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    store.setReminder(n, when);
    _toast('Reminder set for ${fmtWhen(when)}');
  }

  Future<void> _deleteForever() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    store.deleteForever(n);
    Navigator.pop(context, 'deleted');
  }

  Widget _section(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bg = NoteColors.of(context, n.color);
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final muted = cs.onSurface.withAlpha(160);
        final inTrash = n.trashedAt != null;
        final colors = NoteColors.all(context);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: n.pinned ? 'Unpin' : 'Pin to top',
                icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                onPressed: () => store.togglePin(n),
              ),
              if (!inTrash)
                IconButton(
                  tooltip: n.archived ? 'Unarchive' : 'Archive',
                  icon: Icon(n.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  onPressed: () {
                    store.toggleArchive(n);
                    Navigator.pop(context, 'archived');
                  },
                ),
              if (!inTrash)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    store.trash(n);
                    Navigator.pop(context, 'trashed');
                  },
                ),
              if (inTrash)
                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(Icons.restore_from_trash_outlined),
                  onPressed: () {
                    store.restore(n);
                    Navigator.pop(context, 'restored');
                  },
                ),
              if (inTrash)
                IconButton(
                  tooltip: 'Delete forever',
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: _deleteForever,
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                TextField(
                  controller: titleCtrl,
                  focusNode: titleFocus,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration.collapsed(hintText: 'Title'),
                  onChanged: (v) {
                    n.title = v;
                    _changed();
                  },
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Text'), icon: Icon(Icons.notes)),
                      ButtonSegment(value: true, label: Text('Checklist'), icon: Icon(Icons.checklist)),
                    ],
                    selected: {n.isList},
                    onSelectionChanged: (s) => _setMode(s.first),
                  ),
                ),
                const SizedBox(height: 14),
                if (!n.isList)
                  TextField(
                    controller: bodyCtrl,
                    minLines: 6,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: tt.bodyLarge?.copyWith(height: 1.5),
                    decoration: const InputDecoration.collapsed(hintText: 'Write anything…'),
                    onChanged: (v) {
                      n.body = v;
                      _changed();
                    },
                  ),
                if (n.isList) ...[
                  for (final it in n.items)
                    Row(
                      key: ValueKey(it.id),
                      children: [
                        Checkbox(
                          value: it.done,
                          onChanged: (v) {
                            it.done = v ?? false;
                            _changed();
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _c(it),
                            focusNode: _f(it),
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            onEditingComplete: () {},
                            onSubmitted: (_) => _newItemAfter(it),
                            style: tt.bodyLarge?.copyWith(
                              decoration: it.done ? TextDecoration.lineThrough : null,
                              color: it.done ? muted : null,
                            ),
                            decoration: const InputDecoration.collapsed(hintText: 'Item'),
                            onChanged: (v) {
                              it.text = v;
                              _changed();
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          icon: Icon(Icons.close, size: 18, color: muted),
                          onPressed: () => _removeItem(it),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.add, size: 22, color: muted),
                      ),
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          focusNode: addFocus,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.sentences,
                          onEditingComplete: () {},
                          style: tt.bodyLarge,
                          decoration: const InputDecoration.collapsed(hintText: 'Add item'),
                          onSubmitted: (v) {
                            if (v.trim().isEmpty) return;
                            _insertAfter(null, v.trim());
                            addCtrl.clear();
                            addFocus.requestFocus();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (n.items.any((i) => i.done))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _removeTicked,
                        icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                        label: const Text('Remove ticked items'),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Divider(color: cs.onSurface.withAlpha(30)),

                // Color
                _section('Color', Icons.palette_outlined, muted),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < colors.length; i++)
                      Semantics(
                        label: NoteColors.names[i],
                        selected: n.color == i,
                        button: true,
                        child: InkResponse(
                          radius: 22,
                          onTap: () {
                            n.color = i;
                            _changed();
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: n.color == i ? cs.onSurface : cs.onSurface.withAlpha(50),
                                width: n.color == i ? 2.5 : 1,
                              ),
                            ),
                            child: n.color == i ? Icon(Icons.check, size: 18, color: cs.onSurface) : null,
                          ),
                        ),
                      ),
                  ],
                ),

                // Label
                _section('Label', Icons.label_outline, muted),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final l in kLabels)
                      ChoiceChip(
                        label: Text(l),
                        selected: n.label == l,
                        onSelected: (_) {
                          n.label = n.label == l ? null : l;
                          _changed();
                        },
                      ),
                  ],
                ),

                // Reminder
                _section('Reminder', Icons.notifications_none, muted),
                if (n.reminder != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      (n.overdue ? 'Overdue since ' : '') +
                          fmtWhen(n.reminder!) +
                          (n.repeat == Repeat.none ? '' : ', ${n.repeat.label.toLowerCase()}'),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: n.overdue ? cs.error : null,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final e in kQuickTimes.entries)
                      ActionChip(
                        label: Text(e.key),
                        onPressed: () {
                          final when = e.value();
                          store.setReminder(n, when);
                          _toast('Reminder set for ${fmtWhen(when)}');
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.event),
                      label: const Text('Pick date & time'),
                    ),
                    DropdownButton<Repeat>(
                      value: n.repeat,
                      underline: const SizedBox(),
                      onChanged: (r) {
                        if (r != null) store.setRepeat(n, r);
                      },
                      items: [
                        for (final r in Repeat.values) DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                    ),
                    if (n.reminder != null)
                      TextButton.icon(
                        onPressed: () => _toast(store.complete(n)),
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                      ),
                    if (n.reminder != null)
                      TextButton.icon(
                        onPressed: () => store.setReminder(n, null),
                        icon: const Icon(Icons.notifications_off_outlined),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Saved automatically · edited ${ago(DateTime.now().difference(n.updated))}',
                    style: tt.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ),
        );
      },
    );
  }
}
