import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:atelier/main.dart';
import 'package:atelier/data/models.dart';
import 'package:atelier/ui/decks.dart';
import 'package:atelier/ui/editor.dart';
import 'package:atelier/ui/entry_detail.dart';
import 'package:atelier/ui/foundation.dart';
import 'package:atelier/ui/study.dart';
import 'package:atelier/ui/writing_field.dart';
import 'package:atelier/ui/reminders.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline creation study reminders deletion and performance', (
    tester,
  ) async {
    final app = await createApp();
    await app.setPreferences({
      'onboarded': true,
      'theme': 'light',
      'motion': 'full',
    });
    await tester.pumpWidget(AtelierApp(app: app));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    Future<void> waitUntil(bool Function() predicate) async {
      for (var attempt = 0; attempt < 80 && !predicate(); attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(predicate(), isTrue);
      await tester.pumpAndSettle();
    }

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await shot('home-light');
    final context = tester.element(find.text('Atelier'));
    void push(Widget page) {
      Navigator.of(context).push(deskRoute(context, page));
    }

    if (!app.notifications.permitted) {
      push(const RemindersPage());
      await tester.pumpAndSettle();
      debugPrint('ATELIER_PERMISSION_PROMPT');
      await tester.tap(find.text('Enable notifications'));
      for (
        var attempt = 0;
        attempt < 600 && !app.notifications.permitted;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(app.notifications.permitted, isTrue);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
    }

    final now = DateTime.now();
    await app.saveEntry(
      Entry(
        id: 'device-note',
        deckId: 'cs',
        front: 'Submit assignment on 2030/10/29 at 4 pm',
        note: true,
        due: now,
        created: now,
        style: PaperStyle.sticky,
        tint: 1,
      ),
    );
    push(const EntryEditor(entryId: 'device-note'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(WritingField));
    final field = find.descendant(
      of: find.byType(WritingField),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    final controller = tester.widget<TextField>(field).controller!;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    controller.value = const TextEditingValue(
      text: 'Call Alex tomorrow at 10 am',
      selection: TextSelection.collapsed(offset: 25),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.text, 'Call Alex tomorrow at 10 am');
    final before = controller.text;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();
    expect(controller.text, before);
    expect(controller.selection.extentOffset, 4);
    controller.selection = TextSelection.collapsed(offset: before.length);
    await shot('editor-keyboard');
    await tester.tap(find.text('Save').first);
    await waitUntil(
      () => app.entry('device-note')?.front == 'Call Alex tomorrow at 10 am',
    );
    expect(app.entry('device-note')!.front, 'Call Alex tomorrow at 10 am');
    expect(app.reminderFor('device-note'), isNotNull);
    ScaffoldMessenger.of(context).clearSnackBars();
    push(const DeckDetail(deckId: 'cs'));
    await tester.pumpAndSettle();
    await shot('deck-light');
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    push(const StudyPage(entryIds: ['sample-0'], title: 'Data Structures'));
    await tester.pumpAndSettle();
    await shot('study-front');
    await tester.tap(find.text('PROMPT'));
    await tester.pumpAndSettle();
    await shot('study-back');
    await tester.ensureVisible(find.text('Good'));
    await tester.tap(find.text('Good'));
    await waitUntil(() => find.text('Session Complete').evaluate().isNotEmpty);
    expect(find.text('Session Complete'), findsOneWidget);
    await shot('session-complete');
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    // Return to the GPU surface before collecting frame timings. Screenshot
    // readback through an ImageView would distort these measurements.
    await const MethodChannel('plugins.flutter.io/integration_test')
        .invokeMethod<void>('revertFlutterImage');
    await tester.pumpAndSettle();
    final timings = <String, dynamic>{};
    for (final mode in MotionMode.values) {
      await app.setPreferences({'motion': mode.name});
      await tester.pumpAndSettle();
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> values) => frames.addAll(values);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final clock = Stopwatch()..start();
      push(
        const StudyPage(
          entryIds: ['sample-1', 'sample-2'],
          title: 'Performance sample',
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('PROMPT'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Good'));
        await tester.tap(find.text('Good'));
        await waitUntil(
          () => find
              .text(i == 0 ? 'PROMPT' : 'Session Complete')
              .evaluate()
              .isNotEmpty,
        );
      }
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, -450),
        900,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 450),
        900,
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      SchedulerBinding.instance.removeTimingsCallback(collect);
      final build =
          frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final raster =
          frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      double percentile(List<double> list, double p) =>
          list.isEmpty ? 0 : list[((list.length - 1) * p).round()];
      timings[mode.name] = {
        'frames': frames.length,
        'wall_ms': clock.elapsedMilliseconds,
        'build_p95_ms': percentile(build, .95),
        'raster_p95_ms': percentile(raster, .95),
        'build_max_ms': build.isEmpty ? 0 : build.last,
        'raster_max_ms': raster.isEmpty ? 0 : raster.last,
        'frames_over_16_67_ms': frames
            .where(
              (f) =>
                  f.buildDuration.inMicroseconds > 16670 ||
                  f.rasterDuration.inMicroseconds > 16670,
            )
            .length,
      };
    }
    await app.setPreferences({'theme': 'dark', 'motion': 'full'});
    await const MethodChannel('plugins.flutter.io/integration_test')
        .invokeMethod<void>('convertFlutterSurfaceToImage');
    await tester.pumpAndSettle();
    await shot('home-dark');
    push(const EntryDetail(entryId: 'device-note'));
    await tester.pumpAndSettle();
    await shot('note-sticky-dark');
    await tester.ensureVisible(find.text('Delete paper'));
    await tester.tap(find.text('Delete paper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(app.entry('device-note'), isNotNull);
    for (final effect in DeleteEffect.values) {
      await app.setPreferences({'deleteEffect': effect.name});
      await tester.tap(find.text('Delete paper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await waitUntil(() => app.entry('device-note') == null);
      expect(app.entry('device-note'), isNull);
      await tester.tap(find.text('Undo'));
      await waitUntil(() => app.entry('device-note') != null);
      expect(app.entry('device-note'), isNotNull);
      ScaffoldMessenger.of(context).clearSnackBars();
      push(const EntryDetail(entryId: 'device-note'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete paper'));
    }
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    // Two near-future OS reminders are left for host-side background/process-death
    // checks. This fixture uses the real app DB so a cold tap resolves correctly.
    final first = DateTime.now().add(const Duration(minutes: 2));
    await app.saveEntry(
      Entry(
        id: 'device-alert-bg',
        deckId: 'cs',
        front: 'Background reminder acceptance probe',
        note: true,
        due: now,
        created: now,
      ),
    );
    await app.saveEntry(
      Entry(
        id: 'device-alert-closed',
        deckId: 'cs',
        front: 'Closed-process reminder acceptance probe',
        note: true,
        due: now,
        created: now,
      ),
    );
    await app.saveReminder(
      Reminder(
        entryId: 'device-alert-bg',
        title: 'Atelier background delivery test',
        at: first,
      ),
    );
    await app.saveReminder(
      Reminder(
        entryId: 'device-alert-closed',
        title: 'Atelier closed-process delivery test',
        at: first.add(const Duration(minutes: 3)),
      ),
    );
    await app.setPreferences({
      'theme': 'light',
      'motion': 'full',
      'deleteEffect': 'shred',
    });
    final report = {
      'performance': timings,
      'permission': app.notifications.permitted,
      'scheduled_ids': app.notifications.scheduled.toList(),
      'background_due': first.toIso8601String(),
      'closed_due': first.add(const Duration(minutes: 3)).toIso8601String(),
      'timezone': DateTime.now().timeZoneName,
    };
    binding.reportData = {...?binding.reportData, ...report};
    debugPrint('ATELIER_REPORT ${jsonEncode(report)}');
    expect(tester.takeException(), isNull);
  });
}
