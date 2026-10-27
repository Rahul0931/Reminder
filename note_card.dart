import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

class NoteColors {
  static const light = [
    Color(0xFFFFF0A0), // yellow
    Color(0xFFC8EFD4), // green
    Color(0xFFCFE4FF), // blue
    Color(0xFFFFD5DE), // pink
    Color(0xFFE3D8FF), // purple
    Color(0xFFFFDBBD), // orange
    Color(0xFFFFFFFF), // white
  ];
  static const dark = [
    Color(0xFF4A4322),
    Color(0xFF23443A),
    Color(0xFF223A57),
    Color(0xFF4E2A35),
    Color(0xFF393058),
    Color(0xFF4D3525),
    Color(0xFF262D37),
  ];
  static const names = ['Yellow', 'Green', 'Blue', 'Pink', 'Purple', 'Orange', 'White'];

  static List<Color> all(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static Color of(BuildContext context, int i) => all(context)[(i < 0 || i > 6) ? 0 : i];
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleItem,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(CheckItem) onToggleItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = note;
    final muted = cs.onSurface.withAlpha(166);
    final now = DateTime.now();

    final tags = <Widget>[];
    if (n.reminder != null) {
      final late = n.overdue;
      tags.add(_Tag(
        icon: n.repeat == Repeat.none ? Icons.notifications_none : Icons.repeat,
        text: late
            ? 'Overdue · ${ago(now.difference(n.reminder!))}'
            : fmtWhen(n.reminder!) + (n.repeat == Repeat.none ? '' : ' · ${n.repeat.short}'),
        bg: late ? cs.error : null,
        fg: late ? cs.onError : null,
      ));
    }
    if (n.label != null) tags.add(_Tag(text: n.label!));
    if (n.example) tags.add(const _Tag(text: 'Example', outlined: true));
    if (n.trashedAt != null) {
      final left = math.max(1, 30 - now.difference(n.trashedAt!).inDays);
      tags.add(_Tag(text: 'Deletes in $left days'));
    }

    final hasTitle = n.title.trim().isNotEmpty;

    return Material(
      color: NoteColors.of(context, n.color),
      elevation: 1.5,
      shadowColor: Colors.black54,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle || n.pinned)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        n.title.trim(),
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                    ),
                    if (n.pinned)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.push_pin, size: 16, color: muted),
                      ),
                  ],
                ),
              if (!n.isList && n.body.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: hasTitle ? 6 : 0),
                  child: Text(
                    n.body.trim(),
                    maxLines: 9,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              if (n.isList) ...[
                const SizedBox(height: 4),
                for (final it in n.items.take(7))
                  InkWell(
                    onTap: () => onToggleItem(it),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            it.done ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 20,
                            color: it.done ? muted : cs.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              it.text,
                              style: tt.bodyMedium?.copyWith(
                                decoration: it.done ? TextDecoration.lineThrough : null,
                                color: it.done ? muted : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (n.items.length > 7)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 2),
                    child: Text('+${n.items.length - 7} more',
                        style: tt.bodySmall?.copyWith(color: muted)),
                  ),
                if (n.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${n.items.where((i) => i.done).length}/${n.items.length} done',
                      style: tt.bodySmall?.copyWith(color: muted),
                    ),
                  ),
              ],
              if (!n.hasContent) Text('Empty note', style: tt.bodyMedium?.copyWith(color: muted)),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: tags),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.icon, this.bg, this.fg, this.outlined = false});

  final String text;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = fg ?? cs.onSurface.withAlpha(200);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? null : (bg ?? cs.onSurface.withAlpha(22)),
        borderRadius: BorderRadius.circular(99),
        border: outlined ? Border.all(color: color.withAlpha(120)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Masonry-style board: notes flow into the shortest column.
class NoteBoard extends StatelessWidget {
  const NoteBoard({super.key, required this.notes, required this.itemBuilder});

  final List<Note> notes;
  final Widget Function(Note) itemBuilder;

  static double _estimate(Note n) {
    var h = 50.0;
    h += (n.title.length / 18).ceil() * 22;
    if (n.isList) {
      h += math.min(n.items.length, 8) * 26 + 20;
    } else {
      h += math.min((n.body.length / 24).ceil(), 9) * 20;
    }
    if (n.reminder != null || n.label != null) h += 34;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(2, math.min(6, (c.maxWidth / 230).floor()));
      final heights = List<double>.filled(cols, 0);
      final columns = List.generate(cols, (_) => <Widget>[]);
      for (final n in notes) {
        var best = 0;
        for (var i = 1; i < cols; i++) {
          if (heights[i] < heights[best]) best = i;
        }
        columns[best].add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: itemBuilder(n),
        ));
        heights[best] += _estimate(n);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cols; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columns[i],
              ),
            ),
          ],
        ],
      );
    });
  }
}
