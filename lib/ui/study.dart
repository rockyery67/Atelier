import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/sound.dart';
import 'editor.dart';
import 'foundation.dart';

class StudyPage extends StatefulWidget {
  final List<String> entryIds;
  final String title;
  const StudyPage({super.key, required this.entryIds, required this.title});
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  int index = 0;
  bool revealed = false, saving = false;
  final ratings = <Rating>[];
  final started = DateTime.now();
  @override
  void initState() {
    super.initState();
  }

  Future<void> rate(Entry e, Rating rating) async {
    if (!revealed || saving) return;
    setState(() => saving = true);
    try {
      await context.app.rate(e, rating);
      if (!mounted) return;
      context.app.sound(
        index + 1 == widget.entryIds.length
            ? DeskSound.complete
            : DeskSound.shuffle,
      );
      setState(() {
        ratings.add(rating);
        index++;
        revealed = false;
      });
    } catch (e) {
      if (mounted) {
        message(context, 'Review could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (index >= widget.entryIds.length) {
      final recall = ratings
          .where((r) => r == Rating.good || r == Rating.easy)
          .length;
      return Scaffold(
        appBar: deskAppBar(context, 'Session Complete'),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CompletionMark(),
                const SizedBox(height: 28),
                Text(
                  'A little more remembered.',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  '${ratings.length} cards reviewed Â· $recall recalled with ease',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.muted),
                ),
                const SizedBox(height: 24),
                Panel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric('${ratings.length}', 'Reviewed'),
                      _metric(
                        '${ratings.where((r) => r == Rating.again).length}',
                        'Again',
                      ),
                      _metric(
                        '${DateTime.now().difference(started).inMinutes + 1}m',
                        'Quiet time',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.done),
                  label: const Text('Back to my desk'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final e = app.entry(widget.entryIds[index]);
    if (e == null) {
      return Scaffold(
        appBar: deskAppBar(context, 'Study Session'),
        body: EmptyDesk(
          'This card is no longer here',
          'Continue with the next card.',
          action: FilledButton(
            onPressed: () => setState(() => index++),
            child: const Text('Continue'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: deskAppBar(context, 'Study Session'),
      body: LayoutBuilder(
        builder: (context, limits) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE SESSION',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: context.muted,
                        ),
                      ),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${index + 1} / ${widget.entryIds.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: index / widget.entryIds.length,
                minHeight: 4,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 26),
            AnimatedSwitcher(
              duration: context.duration(250),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.08, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: GestureDetector(
                key: ValueKey(e.id),
                onTap: () {
                  if (!revealed) {
                    setState(() => revealed = true);
                    app.sound(DeskSound.flip);
                  }
                },
                child: Semantics(
                  button: true,
                  label: revealed ? 'Answer' : 'Tap to reveal answer',
                  child: _FlipPaper(
                    entry: e,
                    revealed: revealed,
                    height: (limits.maxHeight - 440).clamp(220.0, 480.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              revealed
                  ? 'How well did you remember?'
                  : 'Tap the paper to reveal the other side',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YOUR NEXT REVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: context.muted,
                  ),
                ),
                Text(
                  'Atelier spaced review',
                  style: TextStyle(fontSize: 10, color: context.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: Rating.values.map((r) {
                final i = r.index;
                const backgrounds = [
                  Color(0xfffbe7e4),
                  Color(0xfffff0d3),
                  Color(0xffe2eddb),
                  Color(0xffe5eff9),
                ];
                const foregrounds = [
                  Color(0xff88362b),
                  Color(0xff795011),
                  Color(0xff365c2b),
                  Color(0xff2e567e),
                ];
                final days = ReviewSchedule.interval(e, r);
                final interval = days < .01
                    ? '1 min'
                    : days < 1
                    ? '${(days * 24).round()} h'
                    : '${days.round()} d';
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 3 ? 0 : 7),
                    child: FilledButton(
                      onPressed: revealed && !saving ? () => rate(e, r) : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 2,
                        ),
                        backgroundColor: context.dark
                            ? Color.lerp(backgrounds[i], ink, .8)
                            : backgrounds[i],
                        foregroundColor: context.dark
                            ? backgrounds[i]
                            : foregrounds[i],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            ['Again', 'Hard', 'Good', 'Easy'][i],
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            interval,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: () => guarded(
                      context,
                      () => app.saveEntry(e.copy(bookmarked: !e.bookmarked)),
                    ),
                    icon: Icon(
                      e.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                    ),
                    label: const Text('Flag'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      deskRoute(context, EntryEditor(entryId: e.id)),
                    ),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish later'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String value, String label) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineMedium),
      Text(label, style: TextStyle(fontSize: 10, color: context.muted)),
    ],
  );
}

class _FlipPaper extends StatelessWidget {
  final Entry entry;
  final bool revealed;
  final double height;
  const _FlipPaper({
    required this.entry,
    required this.revealed,
    required this.height,
  });
  @override
  Widget build(BuildContext context) {
    // Construct each face once per state change. Animation frames only update
    // the transform, keeping typography and dot painting outside the ticker.
    final front = RepaintBoundary(child: _face(context, false));
    final answer = RepaintBoundary(child: _face(context, true));
    return TweenAnimationBuilder<double>(
      tween: Tween(end: revealed ? 1 : 0),
      duration: context.duration(450),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final back = value >= .5;
        final angle = context.motion == MotionMode.full
            ? (back ? value - 1 : value) * math.pi
            : 0.0;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateY(angle),
          child: back ? answer : front,
        );
      },
    );
  }

  Widget _face(BuildContext context, bool back) => Paper(
    style: entry.style,
    tint: entry.tint,
    dots: true,
    child: SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.tags.firstOrNull ?? 'A small discovery',
                  style: TextStyle(fontSize: 11, color: context.muted),
                ),
              ),
              const Icon(Icons.draw_outlined, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            back ? 'ANSWER' : 'PROMPT',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: context.muted,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('${entry.id}-$back'),
              child: EntryContent(entry, answer: back),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                back ? Icons.check : Icons.touch_app_outlined,
                size: 16,
                color: context.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  back
                      ? 'Take a moment, then choose a rating.'
                      : 'Tap card to inspect answer',
                  style: TextStyle(fontSize: 11, color: context.muted),
                ),
              ),
              Text(
                'Atelier',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  color: context.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
