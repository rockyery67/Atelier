import 'package:flutter/material.dart';

import '../services/sound.dart';
import 'deletion.dart';
import 'editor.dart';
import 'foundation.dart';
import 'reminders.dart';

class EntryDetail extends StatefulWidget {
  final String entryId;
  const EntryDetail({super.key, required this.entryId});
  @override
  State<EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<EntryDetail> {
  final boundary = GlobalKey();
  bool answer = false, deleting = false;
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final e = app.entry(widget.entryId);
    if (e == null) {
      return Scaffold(
        appBar: deskAppBar(context, 'Your desk'),
        body: const EmptyDesk(
          'This paper has been cleared',
          'Undo from the message below to restore it.',
        ),
      );
    }
    final reminder = app.reminderFor(e.id);
    return Scaffold(
      appBar: deskAppBar(
        context,
        e.note ? 'Personal Note' : 'Flashcard',
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => Navigator.push(
              context,
              deskRoute(context, EntryEditor(entryId: e.id)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            app.deck(e.deckId)?.title ?? '',
            style: TextStyle(color: context.muted, fontSize: 12),
          ),
          const SizedBox(height: 30),
          RepaintBoundary(
            key: boundary,
            child: Paper(
              tint: e.tint,
              style: e.style,
              dots: !e.note,
              child: EntryContent(e, answer: answer),
            ),
          ),
          const SizedBox(height: 28),
          if (!e.note)
            FilledButton.icon(
              onPressed: () {
                setState(() => answer = !answer);
                app.sound(DeskSound.flip);
              },
              icon: const Icon(Icons.flip),
              label: Text(answer ? 'Show question' : 'Reveal answer'),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => guarded(
                  context,
                  () => app.saveEntry(e.copy(bookmarked: !e.bookmarked)),
                ),
                icon: Icon(
                  e.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                label: Text(e.bookmarked ? 'Bookmarked' : 'Bookmark'),
              ),
              TextButton.icon(
                onPressed: () {
                  app.sound(e.pinned ? DeskSound.pinOut : DeskSound.pinIn);
                  guarded(
                    context,
                    () => app.saveEntry(e.copy(pinned: !e.pinned)),
                  );
                },
                icon: AnimatedSwitcher(
                  duration: context.duration(),
                  child: Icon(
                    e.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    key: ValueKey(e.pinned),
                  ),
                ),
                label: Text(e.pinned ? 'Unpin from top' : 'Pin to top'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A little nudge',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  reminder == null
                      ? 'Attach a reminder to this paper.'
                      : readableDate(
                          reminder.next(DateTime.now()) ?? reminder.at,
                        ),
                  style: TextStyle(color: context.muted),
                ),
                if (reminder != null)
                  Text(
                    reminder.enabled
                        ? app.notifications.status
                        : 'Reminder disabled',
                    style: TextStyle(color: context.muted, fontSize: 11),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final r = await chooseReminder(
                      context,
                      e,
                      existing: reminder,
                    );
                    if (r != null && context.mounted) {
                      await guarded(context, () => app.saveReminder(r));
                    }
                  },
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: Text(reminder == null ? 'Remind Me' : 'Edit reminder'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!e.note)
            Text(
              'Next review: ${readableDate(e.due)}\n${e.repetitions} reviews · ${e.intervalDays.toStringAsFixed(1)} day interval',
              style: TextStyle(fontSize: 12, color: context.muted),
            ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: deleting
                ? null
                : () async {
                    setState(() => deleting = true);
                    final deleted = await Deletion.perform(
                      context,
                      e,
                      boundary,
                    );
                    if (context.mounted) {
                      if (deleted) {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      } else {
                        setState(() => deleting = false);
                      }
                    }
                  },
            icon: const Icon(Icons.delete_outline, color: terracotta),
            label: const Text(
              'Delete paper',
              style: TextStyle(color: terracotta),
            ),
          ),
        ],
      ),
    );
  }
}
