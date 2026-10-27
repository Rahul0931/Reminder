import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../quick_parse.dart';
import '../reminders.dart';
import '../store.dart';
import 'editor.dart';
import 'note_card.dart';
import 'reminder_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final NoteStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  NoteStore get store => widget.store;

  int view = 0; // 0 notes, 1 reminders, 2 archive, 3 trash
  String? label;
  String query = '';
  bool searching = false;
  final quickCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  Timer? _tick;
  int _ticks = 0;
  final List<String> _alertQueue = [];
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check every 5 seconds so the big alert appears on time while the app is open.
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkDue();
      if (++_ticks % 6 == 0) {
        store.rollRepeats();
        if (mounted) setState(() {});
      }
    });
    Reminders.onResponse = _onNotification;
    final r = Reminders.launchResponse;
    String? launchId;
    String? launchAction;
    if (r != null && r.payload != null) {
      Reminders.launchResponse = null;
      launchId = r.payload!;
      launchAction = r.actionId;
    }
    final lid = launchId;
    final laction = launchAction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lid != null) _onNotification(lid, laction);
      _checkDue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    quickCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      store.flush();
    }
    if (state == AppLifecycleState.resumed) {
      _checkDue();
      store.rollRepeats();
      if (mounted) setState(() {});
    }
  }

  // ---------- actions ----------
  void _onNotification(String id, String? action) {
    final n = store.byId(id);
    if (n == null || !mounted) return;
    if (action == 'snooze') {
      store.snooze(n, const Duration(minutes: 10));
      _snack('Snoozed for 10 minutes');
    } else if (action == 'done') {
      _snack(store.complete(n));
    } else {
      // Notification tapped, or the app was opened over the lock screen.
      _showAlert(n);
    }
  }

  // ---------- half-screen reminder alert ----------
  void _checkDue() {
    if (!mounted) return;
    for (final n in store.dueForAlert()) {
      _showAlert(n);
    }
  }

  void _showAlert(Note n) {
    if (!_alertQueue.contains(n.id)) _alertQueue.add(n.id);
    _pumpAlerts();
  }

  Future<void> _pumpAlerts() async {
    if (_alertOpen || !mounted || _alertQueue.isEmpty) return;
    final n = store.byId(_alertQueue.removeAt(0));
    if (n == null) {
      _pumpAlerts();
      return;
    }
    _alertOpen = true;
    final when = n.reminder ?? DateTime.now();
    store.markShown(n);
    HapticFeedback.heavyImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ReminderSheet(note: n, when: when),
    );
    _alertOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'done':
        _snack(store.complete(n));
      case 'snooze10':
        store.snooze(n, const Duration(minutes: 10));
        _snack('Snoozed for 10 minutes');
      case 'snooze60':
        store.snooze(n, const Duration(hours: 1));
        _snack('Snoozed for 1 hour');
      case 'tomorrow':
        store.snooze(n, null);
        _snack('Snoozed to tomorrow, 9:00 AM');
      case 'open':
        Reminders.sync(n); // clears the notification from the tray
        _open(n);
      default:
        Reminders.sync(n);
    }
    _pumpAlerts();
  }

  void _snack(String msg, {VoidCallback? undo}) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      action: undo == null ? null : SnackBarAction(label: 'Undo', onPressed: undo),
    ));
  }

  Future<void> _open(Note n) async {
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => EditorPage(store: store, noteId: n.id)),
    );
    store.removeIfEmpty(n.id);
    if (!mounted) return;
    switch (res) {
      case 'trashed':
        _snack('Moved to trash', undo: () => store.restore(n));
      case 'archived':
        _snack(n.archived ? 'Archived' : 'Moved back to notes', undo: () => store.toggleArchive(n));
      case 'restored':
        _snack('Restored');
      case 'deleted':
        _snack('Deleted forever');
    }
  }

  void _addQuick({bool list = false}) {
    final text = quickCtrl.text.trim();
    if (text.isEmpty && !list) {
      _open(store.create(label: label));
      return;
    }
    final p = text.isEmpty ? const Parsed('', null) : parseQuick(text);
    final n = store.create(
      title: p.title,
      isList: list,
      reminder: p.when,
      color: list ? 1 : (p.when != null ? 2 : 0),
      label: label,
    );
    quickCtrl.clear();
    setState(() {
      if (view != 0) view = 0;
    });
    if (list) {
      _open(n);
      return;
    }
    final when = p.when;
    _snack(when != null ? 'Reminder set for ${fmtWhen(when)}' : 'Note added');
  }

  Future<bool> _confirm(String title, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return r ?? false;
  }

  void _actions(Note n) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        void run(VoidCallback f) {
          Navigator.pop(ctx);
          f();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: n.trashedAt != null
                ? [
                    ListTile(
                      leading: const Icon(Icons.restore_from_trash_outlined),
                      title: const Text('Restore'),
                      onTap: () => run(() {
                        store.restore(n);
                        _snack('Restored');
                      }),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined),
                      title: const Text('Delete forever'),
                      onTap: () => run(() async {
                        if (await _confirm('Delete forever?', 'Delete')) store.deleteForever(n);
                      }),
                    ),
                  ]
                : [
                    ListTile(
                      leading: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                      title: Text(n.pinned ? 'Unpin' : 'Pin to top'),
                      onTap: () => run(() => store.togglePin(n)),
                    ),
                    ListTile(
                      leading: Icon(n.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                      title: Text(n.archived ? 'Unarchive' : 'Archive'),
                      onTap: () => run(() {
                        store.toggleArchive(n);
                        _snack(n.archived ? 'Archived' : 'Moved back to notes',
                            undo: () => store.toggleArchive(n));
                      }),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Delete'),
                      onTap: () => run(() {
                        store.trash(n);
                        _snack('Moved to trash', undo: () => store.restore(n));
                      }),
                    ),
                  ],
          ),
        );
      },
    );
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final list = store.visible(view, label, query);
        final overdue = store.overdue();
        final grouped = view == 0 && query.isEmpty;
        final pinned = grouped ? list.where((n) => n.pinned).toList() : <Note>[];
        final rest = grouped ? list.where((n) => !n.pinned).toList() : list;
        final showExamples = !store.examplesDismissed && store.notes.any((n) => n.example);

        return Scaffold(
          appBar: AppBar(
            title: searching
                ? TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Search notes', border: InputBorder.none),
                    onChanged: (v) => setState(() => query = v),
                  )
                : const Text('Sticky Memo', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: searching ? 'Close search' : 'Search',
                icon: Icon(searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  searching = !searching;
                  if (!searching) {
                    query = '';
                    searchCtrl.clear();
                  }
                }),
              ),
              if (view != 1)
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  onSelected: store.setSort,
                  itemBuilder: (_) => [
                    for (final e in kSorts.entries)
                      CheckedPopupMenuItem<String>(
                        value: e.key,
                        checked: store.sort == e.key,
                        child: Text(e.value),
                      ),
                  ],
                ),
              IconButton(
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: () => store.setTheme(isDark ? ThemeMode.light : ThemeMode.dark),
              ),
              if (view == 3 && list.isNotEmpty)
                IconButton(
                  tooltip: 'Empty trash',
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: () async {
                    if (await _confirm('Empty trash?', 'Empty')) store.emptyTrash();
                  },
                ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              if (view == 0) SliverToBoxAdapter(child: _capture(cs)),
              SliverToBoxAdapter(child: _labelChips()),
              if (showExamples && view == 0) SliverToBoxAdapter(child: _examplesBanner(cs)),
              if (overdue.isNotEmpty && view <= 1) SliverToBoxAdapter(child: _overdueCard(overdue, cs)),
              if (list.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _empty(cs))
              else ...[
                if (pinned.isNotEmpty) ...[
                  _header('Pinned', Icons.push_pin_outlined, cs),
                  _board(pinned),
                ],
                if (pinned.isNotEmpty && rest.isNotEmpty) _header('Others', null, cs),
                if (pinned.isEmpty) const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (rest.isNotEmpty) _board(rest),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
          floatingActionButton: view <= 1
              ? FloatingActionButton(
                  tooltip: 'New note',
                  onPressed: () => _open(store.create(label: label)),
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: view,
            onDestinationSelected: (i) => setState(() => view = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.sticky_note_2_outlined),
                selectedIcon: Icon(Icons.sticky_note_2),
                label: 'Notes',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: overdue.isNotEmpty,
                  label: Text('${overdue.length}'),
                  child: const Icon(Icons.notifications_none),
                ),
                selectedIcon: Badge(
                  isLabelVisible: overdue.isNotEmpty,
                  label: Text('${overdue.length}'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'Reminders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.archive_outlined),
                selectedIcon: Icon(Icons.archive),
                label: 'Archive',
              ),
              const NavigationDestination(
                icon: Icon(Icons.delete_outline),
                selectedIcon: Icon(Icons.delete),
                label: 'Trash',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _capture(ColorScheme cs) {
    final text = quickCtrl.text.trim();
    final p = text.isEmpty ? null : parseQuick(text);
    final when = p?.when;
    final hint = when != null
        ? 'Reminder ${fmtWhen(when)} · "${p!.title}"'
        : text.isEmpty
            ? 'Add a time and it becomes a reminder.'
            : 'Press Enter to save as a note.';
    final hintColor = when != null ? cs.primary : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quickCtrl,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _addQuick(),
                  decoration: InputDecoration(
                    hintText: 'Try "call mom tomorrow 6pm"',
                    prefixIcon: const Icon(Icons.edit_note),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Add',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: _addQuick,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'New checklist',
                icon: const Icon(Icons.checklist),
                onPressed: () => _addQuick(list: true),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(
              children: [
                Icon(when != null ? Icons.notifications_active_outlined : Icons.info_outline,
                    size: 15, color: hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: hintColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelChips() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All'),
              selected: label == null,
              onSelected: (_) => setState(() => label = null),
            ),
          ),
          for (final l in kLabels)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(l),
                selected: label == l,
                onSelected: (_) => setState(() => label = label == l ? null : l),
              ),
            ),
        ],
      ),
    );
  }

  Widget _examplesBanner(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text('These are example notes.', style: TextStyle(color: cs.onSurfaceVariant)),
            TextButton(onPressed: store.removeExamples, child: const Text('Remove examples')),
            TextButton(onPressed: store.keepExamples, child: const Text('Keep them')),
          ],
        ),
      ),
    );
  }

  Widget _overdueCard(List<Note> list, ColorScheme cs) {
    final now = DateTime.now();
    final fg = cs.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        color: cs.errorContainer,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.notifications_active, size: 16, color: fg),
                const SizedBox(width: 6),
                Text('OVERDUE · ${list.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: fg)),
              ]),
              for (final n in list)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _open(n),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: fg)),
                            Text('${fmtWhen(n.reminder!)} · ${ago(now.difference(n.reminder!))}',
                                style: TextStyle(fontSize: 12.5, color: fg.withAlpha(190))),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => store.snooze(n, const Duration(hours: 1)),
                            child: const Text('+1 hour'),
                          ),
                          TextButton(
                            onPressed: () => store.snooze(n, null),
                            child: const Text('Tomorrow'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _snack(store.complete(n)),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String text, IconData? icon, ColorScheme cs) {
    final c = cs.onSurfaceVariant;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c), const SizedBox(width: 6)],
          Text(text.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }

  Widget _board(List<Note> notes) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverToBoxAdapter(
        child: NoteBoard(
          notes: notes,
          itemBuilder: (n) => NoteCard(
            key: ValueKey(n.id),
            note: n,
            onTap: () => _open(n),
            onLongPress: () => _actions(n),
            onToggleItem: (it) => store.toggleItem(n, it),
          ),
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) {
    String title;
    String sub;
    if (query.isNotEmpty) {
      title = 'Nothing matches';
      sub = 'No notes contain "$query".';
    } else if (view == 1) {
      title = 'No reminders yet';
      sub = 'On the Notes tab, type something like "submit assignment friday 5pm".';
    } else if (view == 2) {
      title = 'Archive is empty';
      sub = 'Archive notes you want to keep but not see every day.';
    } else if (view == 3) {
      title = 'Trash is empty';
      sub = 'Deleted notes stay here for 30 days.';
    } else if (label != null) {
      title = 'No $label notes';
      sub = 'Notes you add now get this label.';
    } else {
      title = 'Your board is empty';
      sub = 'Type a note in the box above, or tap +.';
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
