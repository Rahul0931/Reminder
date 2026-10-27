import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import 'note_card.dart';

/// The big alert that covers half the screen when a reminder goes off.
/// Pops with one of: 'done', 'snooze10', 'snooze60', 'tomorrow', 'open', or null.
class ReminderSheet extends StatelessWidget {
  const ReminderSheet({super.key, required this.note, required this.when});

  final Note note;
  final DateTime when;

  String get _message {
    if (note.isList) {
      final left = note.items.where((i) => !i.done && i.text.trim().isNotEmpty).toList();
      if (left.isEmpty) return '';
      return left.map((i) => '•  ${i.text.trim()}').join('\n');
    }
    final b = note.body.trim();
    return b == note.displayTitle ? '' : b;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = NoteColors.of(context, note.color);
    final muted = cs.onSurface.withAlpha(170);
    final msg = _message;
    final repeating = note.repeat != Repeat.none;

    return Container(
      constraints: BoxConstraints(minHeight: mq.size.height * 0.5, maxHeight: mq.size.height * 0.88),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black38)],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + mq.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: muted.withAlpha(80), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _RingingBell(color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REMINDER',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: cs.primary)),
                    const SizedBox(height: 2),
                    Text(
                      fmtWhen(when) + (repeating ? ' · ${note.repeat.short}' : ''),
                      style: tt.titleSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            note.displayTitle,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
          ),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(msg, style: tt.titleMedium?.copyWith(height: 1.45, fontWeight: FontWeight.w400)),
              ),
            ),
          ],
          if (note.label != null) ...[
            const SizedBox(height: 12),
            Text(note.label!, style: tt.labelLarge?.copyWith(color: muted)),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'done'),
            icon: const Icon(Icons.check),
            label: Text(repeating ? 'Done for today' : 'Done'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text('Snooze', style: tt.labelLarge?.copyWith(color: muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _snooze(context, '10 min', 'snooze10')),
              const SizedBox(width: 8),
              Expanded(child: _snooze(context, '1 hour', 'snooze60')),
              const SizedBox(width: 8),
              Expanded(child: _snooze(context, 'Tomorrow', 'tomorrow')),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context, 'open'),
            child: const Text('Open note'),
          ),
        ],
      ),
    );
  }

  Widget _snooze(BuildContext context, String text, String action) => OutlinedButton(
        onPressed: () => Navigator.pop(context, action),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Text(text, maxLines: 1),
      );
}

class _RingingBell extends StatefulWidget {
  const _RingingBell({required this.color});
  final Color color;

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final bell = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: widget.color.withAlpha(36), shape: BoxShape.circle),
      child: Icon(Icons.notifications_active, color: widget.color, size: 28),
    );
    if (reduce) return bell;
    return RotationTransition(
      turns: Tween<double>(begin: -0.035, end: 0.035).animate(_c),
      child: bell,
    );
  }
}
