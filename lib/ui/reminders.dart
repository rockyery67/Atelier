import 'package:flutter/material.dart';

import '../data/models.dart';
import 'foundation.dart';
import 'entry_detail.dart';

Future<Reminder?> chooseReminder(
  BuildContext context,
  Entry entry, {
  Reminder? existing,
  DateTime? initial,
  String? title,
}) => showModalBottomSheet<Reminder>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: sheetMotion(context),
  builder: (_) => ReminderSheet(
    entry: entry,
    existing: existing,
    initial: initial,
    title: title,
  ),
);

class ReminderSheet extends StatefulWidget {
  final Entry entry;
  final Reminder? existing;
  final DateTime? initial;
  final String? title;
  const ReminderSheet({
    super.key,
    required this.entry,
    this.existing,
    this.initial,
    this.title,
  });
  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late DateTime at;
  late RepeatRule repeat;
  late bool enabled;
  late final TextEditingController title;
  String? error;
  @override
  void initState() {
    super.initState();
    at =
        widget.initial ??
        widget.existing?.next(DateTime.now()) ??
        widget.existing?.snoozedUntil ??
        widget.existing?.at ??
        DateTime.now().add(const Duration(hours: 1));
    repeat = widget.existing?.repeat ?? RepeatRule.once;
    enabled = widget.existing?.enabled ?? true;
    title = TextEditingController(
      text:
          widget.title ??
          widget.existing?.title ??
          widget.entry.front.split('\n').first,
    );
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A little nudge, later.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Remind Me · ${DateTime.now().timeZoneName}\nYour device schedules this alert, even when Atelier is closed.',
            style: TextStyle(color: context.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Reminder title'),
            maxLength: 140,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('${at.day}/${at.month}/${at.year}'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: at.isBefore(now) ? now : at,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (picked != null) {
                      setState(
                        () => at = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          at.hour,
                          at.minute,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(TimeOfDay.fromDateTime(at).format(context)),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(at),
                    );
                    if (picked != null) {
                      setState(
                        () => at = DateTime(
                          at.year,
                          at.month,
                          at.day,
                          picked.hour,
                          picked.minute,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RepeatRule>(
            initialValue: repeat,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: RepeatRule.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(switch (r) {
                      RepeatRule.once => 'Once',
                      RepeatRule.daily => 'Every day',
                      RepeatRule.weekly => 'Every week on this day',
                    }),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => repeat = v!),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: enabled,
            onChanged: (v) => setState(() => enabled = v),
          ),
          Text(
            context.app.notifications.status,
            style: TextStyle(fontSize: 12, color: context.muted),
          ),
          if (!context.app.notifications.permitted)
            TextButton.icon(
              onPressed: () async {
                await guarded(context, context.app.enableNotifications);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Allow notifications'),
            ),
          const SizedBox(height: 12),
          Text(
            'Resolved: ${readableDate(at)}\nDelivery may be delayed by battery settings or Focus modes.',
            style: TextStyle(color: context.muted, fontSize: 12),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  setState(() => error = 'Add a reminder title.');
                  return;
                }
                if (enabled && !at.isAfter(DateTime.now())) {
                  setState(() => error = 'Choose a future date and time.');
                  return;
                }
                Navigator.pop(
                  context,
                  Reminder(
                    id: widget.existing?.id ?? 0,
                    entryId: widget.entry.id,
                    title: title.text.trim(),
                    at: at,
                    repeat: repeat,
                    enabled: enabled,
                    automatic: false,
                  ),
                );
              },
              child: const Text('Save reminder'),
            ),
          ),
        ],
      ),
    ),
  );
}

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool past = false;
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final now = DateTime.now();
    final reminders =
        app.data.reminders
            .where((r) => past ? r.next(now) == null : r.next(now) != null)
            .toList()
          ..sort(
            (a, b) => (a.next(now) ?? a.at).compareTo(b.next(now) ?? b.at),
          );
    return Scaffold(
      appBar: deskAppBar(context, 'Reminders'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_none_outlined, size: 30),
                const SizedBox(height: 10),
                Text(
                  'Leave it on your desk.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  app.notificationIssue ?? app.notifications.status,
                  style: TextStyle(color: context.muted),
                ),
                if (!app.notifications.permitted)
                  TextButton(
                    onPressed: () => guarded(context, app.enableNotifications),
                    child: const Text('Enable notifications'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Upcoming')),
              ButtonSegment(value: true, label: Text('Past & disabled')),
            ],
            selected: {past},
            onSelectionChanged: (s) => setState(() => past = s.first),
          ),
          const SizedBox(height: 18),
          if (reminders.isEmpty)
            const EmptyDesk(
              'Nothing to remember just yet',
              'Open any card or note and choose Remind Me.',
            ),
          ...reminders.map((r) {
            final entry = app.entry(r.entryId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch.adaptive(
                          value: r.enabled,
                          onChanged: (v) async {
                            if (v &&
                                !(r.snoozedUntil ?? r.at).isAfter(
                                  DateTime.now(),
                                ) &&
                                r.repeat == RepeatRule.once) {
                              message(
                                context,
                                'Choose a new time before enabling this expired reminder.',
                              );
                              return;
                            }
                            await guarded(
                              context,
                              () => app.saveReminder(r.copy(enabled: v)),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      readableDate(r.next(now) ?? r.at),
                      style: TextStyle(color: context.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.repeat.name} · ${r.automatic ? 'Detected in note' : 'Manually set'}${r.enabled && app.notifications.scheduled.contains(r.id) ? ' · Scheduled' : ''}',
                      style: TextStyle(fontSize: 11, color: context.muted),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: entry == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  deskRoute(
                                    context,
                                    EntryDetail(entryId: entry.id),
                                  ),
                                ),
                          child: const Text('Open'),
                        ),
                        TextButton(
                          onPressed: entry == null
                              ? null
                              : () async {
                                  final changed = await chooseReminder(
                                    context,
                                    entry,
                                    existing: r,
                                  );
                                  if (changed != null && context.mounted) {
                                    await guarded(
                                      context,
                                      () => app.saveReminder(changed),
                                    );
                                  }
                                },
                          child: const Text('Edit'),
                        ),
                        if (r.enabled)
                          TextButton(
                            onPressed: () async {
                              final snoozed = r.copy(
                                snoozedUntil: DateTime.now().add(
                                  const Duration(minutes: 10),
                                ),
                              );
                              await guarded(
                                context,
                                () => app.saveReminder(snoozed),
                              );
                              if (context.mounted) {
                                message(
                                  context,
                                  'Snoozed for 10 minutes. Your repeat schedule stays the same.',
                                );
                              }
                            },
                            child: const Text('+10 min'),
                          ),
                        TextButton(
                          onPressed: () =>
                              guarded(context, () => app.removeReminder(r.id)),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
