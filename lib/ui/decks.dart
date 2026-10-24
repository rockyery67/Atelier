import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models.dart';
import 'editor.dart';
import 'entry_detail.dart';
import 'foundation.dart';
import 'study.dart';

Future<void> editDeck(BuildContext context, {Deck? existing}) async {
  final title = TextEditingController(text: existing?.title),
      description = TextEditingController(text: existing?.description),
      category = TextEditingController(text: existing?.category ?? 'Personal');
  var tint = existing?.tint ?? 0;
  var style = existing?.style ?? PaperStyle.pinned;
  String? error;
  final value = await showModalBottomSheet<Deck>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: sheetMotion(context),
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(c).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'A fresh collection.' : 'Deck Configuration',
                style: Theme.of(c).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: title,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Deck title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A little description',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaperStyle>(
                initialValue: style,
                decoration: const InputDecoration(
                  labelText: 'Default card appearance',
                ),
                items: PaperStyle.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (s) => set(() => style = s!),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: List.generate(
                  paperTints.length,
                  (i) => IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: paperTints[i],
                      foregroundColor: ink,
                    ),
                    tooltip: ['Ivory', 'Peach', 'Sage', 'Lavender', 'White'][i],
                    onPressed: () => set(() => tint = i),
                    icon: Icon(tint == i ? Icons.check : Icons.circle_outlined),
                  ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) {
                      set(() => error = 'Give your deck a title.');
                      return;
                    }
                    Navigator.pop(
                      c,
                      Deck(
                        id: existing?.id ?? const Uuid().v4(),
                        title: title.text.trim(),
                        description: description.text.trim(),
                        category: category.text.trim(),
                        tint: tint,
                        style: style,
                        pinned: existing?.pinned ?? false,
                      ),
                    );
                  },
                  child: Text(existing == null ? 'Create deck' : 'Save deck'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // Route animation may still read controllers during dismissal.
  if (value != null && context.mounted) {
    await guarded(context, () => context.app.saveDeck(value));
  }
  await Future<void>.delayed(const Duration(milliseconds: 350));
  title.dispose();
  description.dispose();
  category.dispose();
}

class DeckTile extends StatelessWidget {
  final Deck deck;
  const DeckTile(this.deck, {super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final cards = app.cards(deck.id);
    final due = cards.where((e) => !e.due.isAfter(DateTime.now())).length;
    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 12),
      child: Pressable(
        onTap: () => Navigator.push(
          context,
          deskRoute(context, DeckDetail(deckId: deck.id)),
        ),
        child: Paper(
          style: deck.style,
          tint: deck.tint,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (context.dark ? Colors.black : Colors.white)
                          .withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      deck.category,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const Spacer(),
                  if (deck.pinned) const Icon(Icons.push_pin, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Handwriting(deck.title, size: 29, maxLines: 2),
              const SizedBox(height: 5),
              Text(
                deck.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 17,
                  fontStyle: FontStyle.italic,
                  color: context.muted,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: terracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$due due',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '  / ${cards.length} cards',
                    style: TextStyle(color: context.muted, fontSize: 10),
                  ),
                  const Spacer(),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (context.dark ? Colors.black : Colors.white)
                          .withValues(alpha: .6),
                    ),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeckDetail extends StatefulWidget {
  final String deckId;
  const DeckDetail({super.key, required this.deckId});
  @override
  State<DeckDetail> createState() => _DeckDetailState();
}

class _DeckDetailState extends State<DeckDetail> {
  String query = '', filter = 'All';
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final deck = app.deck(widget.deckId);
    if (deck == null) {
      return const Scaffold(
        body: EmptyDesk('Deck unavailable', 'Return to your collection.'),
      );
    }
    final cards = app.cards(deck.id);
    final due = app.cards(deck.id, dueOnly: true);
    final reviewed = cards.where((e) => e.repetitions > 0).length;
    final mastery = cards.isEmpty
        ? 0
        : (cards.where((e) => e.intervalDays >= 2).length / cards.length * 100)
              .round();
    final entries =
        app.data.entries
            .where(
              (e) =>
                  e.deckId == deck.id &&
                  (query.isEmpty ||
                      '${e.front} ${e.back} ${e.hint} ${e.tags.join(' ')}'
                          .toLowerCase()
                          .contains(query.toLowerCase())) &&
                  switch (filter) {
                    'Due' => !e.note && !e.due.isAfter(DateTime.now()),
                    'Starred' => e.bookmarked,
                    'Notes' => e.note,
                    'Difficult' =>
                      !e.note && e.repetitions > 0 && e.intervalDays < 1,
                    _ => true,
                  },
            )
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? a.created.compareTo(b.created)
                : a.pinned
                ? -1
                : 1,
          );
    return Scaffold(
      appBar: deskAppBar(
        context,
        'Deck Details',
        actions: [
          IconButton(
            tooltip: deck.pinned ? 'Unpin deck' : 'Pin deck to top',
            onPressed: () => guarded(
              context,
              () => app.saveDeck(deck.copy(pinned: !deck.pinned)),
            ),
            icon: Icon(deck.pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: 'Deck configuration',
            onPressed: () => editDeck(context, existing: deck),
            icon: const Icon(Icons.tune),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        key: PageStorageKey('deck-${deck.id}'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Paper(
                    tint: deck.tint,
                    style: deck.style,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${deck.category.toUpperCase()}  ·  ${cards.length} cards',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.muted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          deck.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          deck.description,
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                            color: context.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$reviewed cards explored',
                          style: TextStyle(fontSize: 11, color: context.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('${due.length}', 'Due today'),
                        _stat('$mastery%', 'Mastery'),
                        _stat(
                          '${cards.isEmpty ? 0 : (cards.fold<double>(0, (sum, e) => sum + e.intervalDays) / cards.length).toStringAsFixed(1)}d',
                          'Avg interval',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: cards.isEmpty
                          ? null
                          : () => Navigator.push(
                              context,
                              deskRoute(
                                context,
                                StudyPage(
                                  entryIds: (due.isEmpty ? cards : due)
                                      .map((e) => e.id)
                                      .toList(),
                                  title: deck.title,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        due.isEmpty
                            ? 'Practice ${cards.length} cards'
                            : 'Start Study Session · ${due.length} due',
                      ),
                    ),
                  ),
                  SectionLabel(
                    'Cards in this deck',
                    trailing: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        deskRoute(context, EntryEditor(deckId: deck.id)),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('New Card'),
                    ),
                  ),
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search prompts, notes, answers…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Due', 'Starred', 'Notes', 'Difficult']
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(
                                  s,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: filter == s,
                                onSelected: (_) => setState(() => filter = s),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyDesk(
                'A fresh sheet of paper',
                'Add a card or note, or try a different search.',
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Pressable(
                    onTap: () => Navigator.push(
                      context,
                      deskRoute(context, EntryDetail(entryId: e.id)),
                    ),
                    child: Paper(
                      tint: e.tint,
                      style: e.style,
                      padding: const EdgeInsets.all(22),
                      child: EntryContent(e, compact: true),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(
                      'Deck Configuration',
                      trailing: TextButton(
                        onPressed: () => editDeck(context, existing: deck),
                        child: const Text('Edit'),
                      ),
                    ),
                    Text(
                      'Default appearance: ${deck.style.name}\nDaily target: ${app.prefs.dailyGoal} reviews\nAlgorithm: Atelier spaced review',
                      style: TextStyle(
                        color: context.muted,
                        height: 1.8,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: TextStyle(fontSize: 10, color: context.muted)),
    ],
  );
}
