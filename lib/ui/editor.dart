import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/models.dart';
import '../data/reminder_parser.dart';
import '../services/sound.dart';
import 'foundation.dart';
import 'reminders.dart';
import 'writing_field.dart';

class EntryEditor extends StatefulWidget {
  final String? entryId, deckId;
  final bool note;
  const EntryEditor({super.key, this.entryId, this.deckId, this.note = false});
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final front = TextEditingController(),
      back = TextEditingController(),
      hint = TextEditingController(),
      tags = TextEditingController();
  late String id, deckId;
  late bool note, clean;
  PaperStyle style = PaperStyle.pinned;
  int tint = 0, side = 0;
  double size = 26;
  DateTime created = DateTime.now();
  Entry? original;
  Reminder? manual;
  Detection detection = const Detection(DetectionState.none);
  bool dismissed = false, saving = false, initialized = false, dirty = false;
  bool removeManualReminder = false;
  String? imagePath, error;
  XFile? picked;
  Timer? _parser;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final app = context.app;
    original = widget.entryId == null ? null : app.entry(widget.entryId!);
    final e = original;
    id = e?.id ?? const Uuid().v4();
    deckId = e?.deckId ?? widget.deckId ?? app.data.decks.first.id;
    final deck = app.deck(deckId)!;
    note = e?.note ?? widget.note;
    clean = e?.cleanPrint ?? app.prefs.cleanPrint;
    size = e?.textSize ?? 26;
    style = e?.style ?? deck.style;
    tint = e?.tint ?? deck.tint;
    created = e?.created ?? DateTime.now();
    front.text = e?.front ?? '';
    back.text = e?.back ?? '';
    hint.text = e?.hint ?? '';
    tags.text = e?.tags.join(', ') ?? '';
    imagePath = e?.imagePath;
    final r = app.reminderFor(id);
    if (r != null && !r.automatic) manual = r;
    front.addListener(_detect);
    _detect();
    dirty = false;
  }

  void _detect() {
    dirty = true;
    _parser?.cancel();
    _parser = Timer(const Duration(milliseconds: 140), () {
      if (mounted) {
        setState(
          () => detection = ReminderParser.parse(
            front.text,
            DateTime.now(),
            defaultMinutes: context.app.prefs.defaultReminderMinutes,
          ),
        );
      }
    });
  }

  Entry draft() => Entry(
    id: id,
    deckId: deckId,
    front: front.text,
    back: back.text,
    hint: hint.text,
    note: note,
    cleanPrint: clean,
    textSize: size,
    style: style,
    tint: tint,
    tags: tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .take(20)
        .toList(),
    imagePath: imagePath,
    created: created,
    due: original?.due ?? DateTime.now(),
    bookmarked: original?.bookmarked ?? false,
    pinned: original?.pinned ?? false,
    repetitions: original?.repetitions ?? 0,
    intervalDays: original?.intervalDays ?? 0,
  );
  Future<void> _save() async {
    if (saving) return;
    if (front.text.trim().isEmpty || (!note && back.text.trim().isEmpty)) {
      setState(
        () => error = note
            ? 'Write something on your note.'
            : 'Add a question and an answer.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final app = context.app;
    try {
      if (picked != null) {
        final directory = Directory(
          p.join((await getApplicationSupportDirectory()).path, 'media'),
        );
        await directory.create(recursive: true);
        final ext = p.extension(picked!.path).isEmpty
            ? '.jpg'
            : p.extension(picked!.path);
        final target = p.join(directory.path, '${const Uuid().v4()}$ext');
        await File(picked!.path).copy(target);
        imagePath = target;
        picked = null;
      }
      final d = ReminderParser.parse(
        front.text,
        DateTime.now(),
        defaultMinutes: app.prefs.defaultReminderMinutes,
      );
      final previousReminder = app.reminderFor(id);
      final auto =
          !dismissed && manual == null && d.state == DetectionState.ready;
      final reminder =
          manual ??
          (auto
              ? Reminder(
                  id: previousReminder?.id ?? 0,
                  entryId: id,
                  title: d.title,
                  at: d.at!,
                  automatic: true,
                )
              : null);
      await app.saveEntry(
        draft(),
        reminder: reminder,
        replaceReminder:
            removeManualReminder ||
            manual != null ||
            previousReminder?.automatic == true ||
            auto,
      );
      app.sound(DeskSound.save);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      if (reminder != null) {
        final stored = app.reminderFor(id)!;
        final scheduled = app.notifications.scheduled.contains(stored.id);
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheduled
                      ? 'Reminder set for ${readableDate(reminder.at)}.'
                      : 'Reminder saved for ${readableDate(reminder.at)}. ${app.notificationIssue ?? app.notifications.status}',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final c = messenger.context;
                      final changed = await chooseReminder(
                        c,
                        draft(),
                        existing: stored,
                      );
                      if (changed != null) await app.saveReminder(changed);
                    },
                    child: const Text('Edit reminder'),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Undo reminder',
              onPressed: () async {
                if (previousReminder == null) {
                  await app.removeReminder(stored.id);
                } else {
                  await app.saveReminder(previousReminder);
                }
              },
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved to your desk.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Could not save. Your writing is still here. $e',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> _leave() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Keep writing?'),
            content: const Text('You have unsaved changes.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep writing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _parser?.cancel();
    front.removeListener(_detect);
    front.dispose();
    back.dispose();
    hint.dispose();
    tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return PopScope(
      canPop: !dirty || saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _leave() && context.mounted) {
          setState(() => dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            original == null
                ? (note ? 'New Note' : 'New Card')
                : 'Edit ${note ? 'Note' : 'Card'}',
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
        body: ListView(
          key: const PageStorageKey('editor'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            DropdownButtonFormField<String>(
              initialValue: deckId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.folder_open_outlined),
                labelText: 'Deck',
              ),
              items: app.data.decks
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (s) => setState(() {
                deckId = s!;
                dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.style_outlined),
                  label: Text('Flashcard'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.edit_note),
                  label: Text('Personal note'),
                ),
              ],
              selected: {note},
              onSelectionChanged: (s) => setState(() {
                note = s.first;
                dirty = true;
              }),
            ),
            if (!note) ...[
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Front · question')),
                  ButtonSegment(value: 1, label: Text('Back · answer')),
                ],
                selected: {side},
                onSelectionChanged: (s) {
                  setState(() => side = s.first);
                  app.sound(DeskSound.flip);
                },
              ),
            ],
            const SizedBox(height: 24),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '◉  LIVE DESK PREVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: side == 0 ? front : back,
                    builder: (_, value, _) => Paper(
                      style: style,
                      tint: tint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Handwriting(
                            value.text.isEmpty
                                ? (note
                                      ? 'A thought worth keeping…'
                                      : side == 0
                                      ? 'Your question begins here…'
                                      : 'The other side of the thought…')
                                : value.text,
                            size: size,
                            clean: clean,
                            maxLines: 5,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            note
                                ? 'PERSONAL NOTE'
                                : side == 0
                                ? 'FRONT · QUESTION'
                                : 'BACK · ANSWER',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              color: context.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ruled notebook editor',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: context.dark
                          ? const Color(0xff242720)
                          : const Color(0xfff8f3e6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        left: BorderSide(
                          color: terracotta.withValues(alpha: .3),
                          width: 3,
                        ),
                      ),
                    ),
                    child: WritingField(
                      key: ValueKey(side),
                      controller: note || side == 0 ? front : back,
                      label: note
                          ? 'Your note'
                          : side == 0
                          ? 'Prompt / question'
                          : 'Answer',
                      clean: clean,
                      size: size,
                      onChanged: (_) {
                        dirty = true;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hint,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => dirty = true,
                    decoration: const InputDecoration(
                      labelText: 'Mnemonic, reflection or citation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    onChanged: (_) => dirty = true,
                    decoration: const InputDecoration(
                      labelText: 'Tags, separated by commas',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                ],
              ),
            ),
            if (detection.state != DetectionState.none || manual != null) ...[
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            manual != null
                                ? 'Manual reminder'
                                : dismissed
                                ? 'Reminder detection dismissed'
                                : detection.state == DetectionState.ready
                                ? 'Reminder detected'
                                : 'Choose a reminder time',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: dismissed
                              ? 'Restore detection'
                              : 'Dismiss detected reminder',
                          onPressed: () => setState(() {
                            dismissed = !dismissed;
                            removeManualReminder =
                                manual != null || removeManualReminder;
                            manual = null;
                            dirty = true;
                          }),
                          icon: Icon(dismissed ? Icons.undo : Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      manual != null
                          ? readableDate(manual!.at)
                          : detection.at != null
                          ? readableDate(detection.at!)
                          : detection.message,
                      style: TextStyle(color: context.muted, fontSize: 12),
                    ),
                    if (!dismissed)
                      TextButton(
                        onPressed: () async {
                          final r = await chooseReminder(
                            context,
                            draft(),
                            existing: manual ?? app.reminderFor(id),
                            initial: detection.at,
                            title: detection.title.isEmpty
                                ? null
                                : detection.title,
                          );
                          if (r != null) {
                            setState(() {
                              manual = r;
                              dirty = true;
                            });
                          }
                        },
                        child: const Text('Inspect / edit date & time'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card Appearance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: PaperStyle.values
                        .map(
                          (s) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: s == PaperStyle.pinned ? 8 : 0,
                                left: s == PaperStyle.sticky ? 8 : 0,
                              ),
                              child: Pressable(
                                onTap: () {
                                  if (style == s) return;
                                  app.sound(
                                    style == PaperStyle.sticky
                                        ? DeskSound.peel
                                        : DeskSound.pinOut,
                                  );
                                  setState(() {
                                    style = s;
                                    dirty = true;
                                  });
                                  Future.delayed(
                                    const Duration(milliseconds: 70),
                                    () {
                                      app.sound(
                                        s == PaperStyle.pinned
                                            ? DeskSound.pinIn
                                            : DeskSound.attach,
                                      );
                                    },
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: context.duration(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 22,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: style == s
                                        ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                        : Theme.of(context).colorScheme.surface,
                                    border: Border.all(
                                      color: style == s
                                          ? context.muted
                                          : Colors.transparent,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        s == PaperStyle.pinned
                                            ? Icons.push_pin_outlined
                                            : Icons.sticky_note_2_outlined,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s == PaperStyle.pinned
                                            ? 'Pinned'
                                            : 'Sticky',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        s == PaperStyle.pinned
                                            ? 'Brass desk tack'
                                            : 'Frosted tape',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: context.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'PAPER CARDSTOCK TINT',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: context.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      paperTints.length,
                      (i) => Semantics(
                        label: [
                          'Warm ivory',
                          'Peach',
                          'Sage',
                          'Lavender',
                          'Clean paper',
                        ][i],
                        selected: tint == i,
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            tint = i;
                            dirty = true;
                          }),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: paperTints[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tint == i ? ink : Colors.black12,
                                width: tint == i ? 2.5 : 1,
                              ),
                            ),
                            child: tint == i
                                ? const Icon(Icons.check, color: ink)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penmanship & size',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Clean print'),
                    subtitle: const Text('A clear alternative to handwriting'),
                    value: clean,
                    onChanged: (v) => setState(() {
                      clean = v;
                      dirty = true;
                    }),
                  ),
                  Row(
                    children: [
                      const Text('A−'),
                      Expanded(
                        child: Slider(
                          value: size,
                          min: 18,
                          max: 34,
                          divisions: 8,
                          label: '${size.round()} pt',
                          onChanged: (v) => setState(() {
                            size = v;
                            dirty = true;
                          }),
                        ),
                      ),
                      Text('${size.round()} pt'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (imagePath != null)
              Panel(
                child: Column(
                  children: [
                    Image.file(
                      File(imagePath!),
                      height: 140,
                      cacheWidth: 600,
                      errorBuilder: (_, _, _) =>
                          const Text('Attachment unavailable'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        imagePath = null;
                        picked = null;
                        dirty = true;
                      }),
                      icon: const Icon(Icons.close),
                      label: const Text('Remove image'),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final f = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1600,
                    maxHeight: 1600,
                    imageQuality: 85,
                  );
                  if (f != null && mounted) {
                    setState(() {
                      picked = f;
                      imagePath = f.path;
                      dirty = true;
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    message(context, 'Could not open image picker: $e');
                  }
                }
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Attach diagram, sketch or photograph'),
            ),
            TextButton.icon(
              onPressed: () async {
                final r = await chooseReminder(
                  context,
                  draft(),
                  existing: manual ?? app.reminderFor(id),
                );
                if (r != null) {
                  setState(() {
                    manual = r;
                    dirty = true;
                  });
                }
              },
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('Remind Me'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : _save,
              child: const Text('Save to my desk'),
            ),
          ],
        ),
      ),
    );
  }
}
