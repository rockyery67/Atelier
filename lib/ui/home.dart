import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../services/sound.dart';
import 'decks.dart';
import 'editor.dart';
import 'entry_detail.dart';
import 'foundation.dart';
import 'reminders.dart';
import 'settings.dart';
import 'study.dart';

class DeskShell extends StatefulWidget {
  const DeskShell({super.key});
  @override
  State<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends State<DeskShell> {
  int tab = 0;
  late final app = context.app;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      app.route.addListener(_route);
      if (app.pendingPayload != null) app.handleTap(app.pendingPayload);
    });
  }

  void _route() {
    final id = app.route.value;
    if (id != null && mounted) {
      app.pendingPayload = null;
      Navigator.of(context).push(deskRoute(context, EntryDetail(entryId: id)));
    }
  }

  @override
  void dispose() {
    app.route.removeListener(_route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: deskAppBar(
      context,
      ['Atelier', 'Collection', 'Progress', 'Settings'][tab],
      home: tab == 0,
      actions: [
        IconButton(
          tooltip: 'Reminders',
          onPressed: () => Navigator.push(
            context,
            deskRoute(context, const RemindersPage()),
          ),
          icon: const Icon(Icons.notifications_none_outlined),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: IndexedStack(
      index: tab,
      children: const [
        HomePage(),
        CollectionPage(),
        ProgressPage(),
        SettingsPage(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'HOME',
        ),
        NavigationDestination(
          icon: Icon(Icons.layers_outlined),
          selectedIcon: Icon(Icons.layers),
          label: 'DECKS',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          label: 'PROGRESS',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: 'SETTINGS'),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PaperStyle? filter;
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final now = DateTime.now();
    final due = app.cards(null, dueOnly: true);
    final priority = due.firstOrNull;
    final deck = priority == null
        ? app.data.decks.firstOrNull
        : app.deck(priority.deckId);
    final waiting = deck == null
        ? <Entry>[]
        : app.cards(deck.id, dueOnly: true);
    final today = app.data.reviews
        .where(
          (r) =>
              r.at.year == now.year &&
              r.at.month == now.month &&
              r.at.day == now.day,
        )
        .length;
    final goal = app.prefs.dailyGoal;
    final ratio = (today / goal).clamp(0.0, 1.0);
    final decks =
        app.data.decks
            .where((d) => filter == null || d.style == filter)
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? 0
                : a.pinned
                ? -1
                : 1,
          );
    return CustomScrollView(
      key: const PageStorageKey('home'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(now).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  now.hour < 12
                      ? 'Good morning, curious mind.'
                      : now.hour < 18
                      ? 'A little time, for you.'
                      : 'A quieter kind of evening.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 30),
                if (deck != null)
                  Transform.rotate(
                    angle: context.motion == MotionMode.full ? -.018 : 0,
                    child: Paper(
                      tint: 0,
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
                                  color: context.dark
                                      ? Colors.black26
                                      : Colors.white60,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  priority == null
                                      ? 'ALL CAUGHT UP'
                                      : 'DUE PRIORITY',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.schedule,
                                size: 13,
                                color: context.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${max(1, waiting.length * 20 ~/ 60)} min review',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Handwriting(deck.title, size: 31, maxLines: 2),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  (context.dark ? Colors.black : Colors.white)
                                      .withValues(alpha: .32),
                              borderRadius: BorderRadius.circular(18),
                              border: Border(
                                left: BorderSide(
                                  color: context.muted.withValues(alpha: .2),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FLASHCARD QUESTION',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    color: context.muted,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Handwriting(
                                  priority?.front ?? 'A fresh thought is always worth keeping.',
                                  size: 25,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 14,
                            runSpacing: 12,
                            children: [
                              Text(
                                '${waiting.length} waiting',
                                style: const TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 18,
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Jakarta',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  deskRoute(
                                    context,
                                    StudyPage(
                                      entryIds:
                                          (waiting.isEmpty
                                                  ? app.cards(deck.id)
                                                  : waiting)
                                              .map((e) => e.id)
                                              .toList(),
                                      title: deck.title,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                iconAlignment: IconAlignment.end,
                                label: Text(
                                  priority == null
                                      ? 'Practice'
                                      : 'Continue Session',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xff8da382),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Daily Study Rhythm',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '$today / $goal cards',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 17,
                              color: context.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          color: Theme.of(context).colorScheme.primary,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              today >= goal
                                  ? 'You made time for your mind.'
                                  : 'A small habit, a lasting memory.',
                              style: TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: context.muted,
                              ),
                            ),
                          ),
                          Text(
                            '${max(0, goal - today)} to go',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quick(
                        Icons.library_add_outlined,
                        'New Deck',
                        () => editDeck(context),
                      ),
                      _quick(
                        Icons.add_circle_outline,
                        'Add Card',
                        () => Navigator.push(
                          context,
                          deskRoute(context, const EntryEditor()),
                        ),
                      ),
                      _quick(Icons.shuffle, 'Shuffle Due', () {
                        if (due.isEmpty) {
                          message(
                            context,
                            'All caught up. Open a deck to practice.',
                          );
                          return;
                        }
                        app.sound(DeskSound.shuffle);
                        final ids = due.map((e) => e.id).toList()..shuffle();
                        Navigator.push(
                          context,
                          deskRoute(
                            context,
                            StudyPage(
                              entryIds: ids,
                              title: 'A shuffled little session',
                            ),
                          ),
                        );
                      }),
                      _quick(
                        Icons.edit_note,
                        'New Note',
                        () => Navigator.push(
                          context,
                          deskRoute(context, const EntryEditor(note: true)),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionLabel(
                  'Archival Decks',
                  trailing: PopupMenuButton<PaperStyle?>(
                    tooltip: 'Filter deck appearance',
                    initialValue: filter,
                    onSelected: (v) => setState(() => filter = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: null,
                        child: Text('All appearances'),
                      ),
                      PopupMenuItem(
                        value: PaperStyle.pinned,
                        child: Text('Pinned'),
                      ),
                      PopupMenuItem(
                        value: PaperStyle.sticky,
                        child: Text('Sticky'),
                      ),
                    ],
                    child: Chip(
                      label: Text(
                        filter?.name ?? 'All',
                        style: const TextStyle(fontSize: 11),
                      ),
                      avatar: const Icon(Icons.filter_list, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: decks.length,
            itemBuilder: (_, i) => DeckTile(decks[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: Column(
              children: [
                Text(
                  '“Memory is the architecture of quiet attention.”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: context.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ATELIER JOURNAL · YOUR OWN LITTLE DESK',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1,
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quick(IconData icon, String text, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 17),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    ),
  );
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  String query = '', filter = 'Decks';
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final decks =
        app.data.decks
            .where(
              (d) => '${d.title} ${d.description} ${d.category}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? 0
                : a.pinned
                ? -1
                : 1,
          );
    final entries =
        app.data.entries
            .where(
              (e) =>
                  (filter != 'Notes' || e.note) &&
                  (filter != 'Bookmarks' || e.bookmarked) &&
                  '${e.front} ${e.back} ${e.tags.join(' ')} ${e.hint}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? b.created.compareTo(a.created)
                : a.pinned
                ? -1
                : 1,
          );
    return CustomScrollView(
      key: const PageStorageKey('collection'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  'Everything, in its place.',
                  trailing: IconButton(
                    tooltip: 'New deck',
                    onPressed: () => editDeck(context),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search your desk…',
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Decks', 'All paper', 'Notes', 'Bookmarks']
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 6),
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
                const SizedBox(height: 8),
                if (filter == 'Notes')
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      deskRoute(context, const EntryEditor(note: true)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('A new personal note'),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: filter == 'Decks' ? decks.length : entries.length,
            itemBuilder: (c, i) {
              if (filter == 'Decks') return DeckTile(decks[i]);
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
                    child: EntryContent(e, compact: true),
                  ),
                ),
              );
            },
          ),
        ),
        if (filter == 'Decks' ? decks.isEmpty : entries.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyDesk(
              'Nothing here just yet',
              'Try a different search, or create something new.',
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final reviews = app.data.reviews.toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    final now = DateTime.now();
    final cards = app.cards(null);
    final successful = reviews
        .where((r) => r.rating == Rating.good || r.rating == Rating.easy)
        .length;
    return ListView(
      key: const PageStorageKey('progress'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Small steps. Lasting ideas.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 22),
        Panel(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric(context, '${reviews.length}', 'Reviews'),
              _metric(
                context,
                '${reviews.isEmpty ? 0 : (successful / reviews.length * 100).round()}%',
                'Recall',
              ),
              _metric(
                context,
                '${app.cards(null, dueOnly: true).length}',
                'Due',
              ),
            ],
          ),
        ),
        const SectionLabel('The past seven days'),
        Panel(
          child: SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final d = DateTime(now.year, now.month, now.day - 6 + i);
                final count = reviews
                    .where(
                      (r) =>
                          r.at.year == d.year &&
                          r.at.month == d.month &&
                          r.at.day == d.day,
                    )
                    .length;
                final ratio = (count / app.prefs.dailyGoal).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$count', style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 6),
                        Container(
                          height: max(4.0, ratio * 100),
                          decoration: BoxDecoration(
                            color: i == 6
                                ? terracotta
                                : context.muted.withValues(alpha: .45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          DateFormat('EE').format(d).substring(0, 1),
                          style: TextStyle(fontSize: 10, color: context.muted),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${cards.where((e) => e.repetitions > 0).length} of ${cards.length} cards explored. Ratings and next-review dates are stored on this device.',
          style: TextStyle(fontSize: 12, color: context.muted),
        ),
        const SectionLabel('Session memory'),
        if (reviews.isEmpty)
          const EmptyDesk(
            'Your rhythm begins with one card',
            'Complete a study session to see your progress here.',
          ),
        ...reviews
            .take(100)
            .map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainer,
                  child: Icon(
                    r.rating == Rating.again ? Icons.replay : Icons.done,
                    size: 19,
                  ),
                ),
                title: Text(
                  app.entry(r.entryId)?.front ?? 'Restored card',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${readableDate(r.at)} · ${r.rating.name}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Text(
                  '${r.intervalDays < 1 ? (r.intervalDays * 24).round() : r.intervalDays.round()}${r.intervalDays < 1 ? 'h' : 'd'}',
                  style: TextStyle(color: context.muted),
                ),
              ),
            ),
      ],
    );
  }

  Widget _metric(BuildContext c, String value, String title) => Column(
    children: [
      Text(value, style: Theme.of(c).textTheme.headlineMedium),
      Text(title, style: TextStyle(fontSize: 10, color: c.muted)),
    ],
  );
}
