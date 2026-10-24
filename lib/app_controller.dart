import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'services/notifications.dart';
import 'services/sound.dart';

class AppController extends ChangeNotifier {
  final LocalStore store;
  final ReminderGateway notifications;
  final DeskAudio? audio;
  Snapshot data = const Snapshot();
  final Set<String> _deleting = {};
  Future<void> _queue = Future.value();
  String? notificationIssue;
  String? pendingPayload;
  final ValueNotifier<String?> route = ValueNotifier(null);
  AppController(this.store, this.notifications, {this.audio});
  Preferences get prefs => data.preferences;
  Entry? entry(String id) => data.entries.where((e) => e.id == id).firstOrNull;
  Deck? deck(String id) => data.decks.where((e) => e.id == id).firstOrNull;
  Reminder? reminderFor(String id) =>
      data.reminders.where((r) => r.entryId == id).firstOrNull;
  List<Entry> cards(String? deckId, {bool dueOnly = false}) => data.entries
      .where(
        (e) =>
            !e.note &&
            (deckId == null || e.deckId == deckId) &&
            (!dueOnly || !e.due.isAfter(DateTime.now())),
      )
      .toList();
  Future<void> initialize({bool seed = true}) async {
    if (seed) await store.seed();
    data = await store.read();
    audio?.preferences = prefs;
    try {
      await notifications.initialize(handleTap);
    } catch (e) {
      notificationIssue =
          'Notifications could not initialize. Your local desk is available. $e';
    }
    await reconcile();
    notifyListeners();
  }

  void handleTap(String? payload) {
    pendingPayload = payload;
    final id = routePayload(payload, data.entries);
    if (id != null) {
      route.value = null;
      route.value = id;
    }
  }

  Future<void> reconcile() async {
    try {
      await notifications.reconcile(data.reminders);
      notificationIssue = null;
    } catch (e) {
      notificationIssue =
          'Notification scheduling needs attention. Your data is saved. $e';
    }
  }

  Future<T> mutate<T>(Future<T> Function() work) {
    final completer = Completer<T>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        final result = await work();
        data = await store.read();
        audio?.preferences = prefs;
        await reconcile();
        notifyListeners();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> saveDeck(Deck deck) => mutate(() => store.saveDeck(deck));
  Future<void> saveEntry(
    Entry entry, {
    Reminder? reminder,
    bool replaceReminder = false,
  }) => mutate(
    () => store.saveEntry(
      entry,
      reminder: reminder,
      replaceReminder: replaceReminder,
    ),
  );
  Future<void> saveReminder(Reminder reminder) =>
      mutate(() => store.saveReminder(reminder));
  Future<void> removeReminder(int id) => mutate(() => store.removeReminder(id));
  Future<void> setPreferences(Json patch) =>
      mutate(() => store.savePreferences(prefs.change(patch)));
  Future<DeletedBundle?> delete(String id) async {
    if (!_deleting.add(id)) return null;
    try {
      return await mutate(() => store.deleteEntry(id));
    } finally {
      _deleting.remove(id);
    }
  }

  Future<void> undo(DeletedBundle bundle, {DateTime? now}) =>
      mutate(() => store.restore(bundle, now ?? DateTime.now()));
  Future<void> rate(Entry entry, Rating rating) => mutate(() async {
    final now = DateTime.now();
    final current = this.entry(entry.id);
    if (current == null) {
      throw StateError('This card was removed before its review was saved.');
    }
    final updated = ReviewSchedule.apply(current, rating, now);
    await store.review(
      updated,
      Review(
        id: const Uuid().v4(),
        entryId: entry.id,
        rating: rating,
        at: now,
        intervalDays: updated.intervalDays,
      ),
    );
  });
  Future<bool> enableNotifications() async {
    final result = await notifications.requestPermission();
    await reconcile();
    notifyListeners();
    return result;
  }

  void sound(DeskSound s) {
    unawaited(audio?.play(s) ?? Future.value());
  }

  Future<void> resume() => mutate(() async {});
}
