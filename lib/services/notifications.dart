import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

String? routePayload(String? payload, Iterable<Entry> entries) {
  if (payload == null) return null;
  try {
    final j = jsonDecode(payload);
    if (j is Map &&
        j['kind'] == 'task' &&
        j['entry'] is String &&
        entries.any((e) => e.id == j['entry'])) {
      return j['entry'] as String;
    }
  } catch (_) {}
  return null;
}

List<Reminder> planReminderRequests(List<Reminder> reminders, DateTime now) {
  final requests = <Reminder>[];
  for (final r in reminders.where((r) => r.enabled)) {
    final snooze = r.snoozedUntil;
    if (snooze != null) {
      if (snooze.isAfter(now)) {
        requests.add(
          r.copy(
            id: 1000000000 + r.id,
            at: snooze,
            repeat: RepeatRule.once,
            clearSnooze: true,
          ),
        );
      }
      if (r.repeat != RepeatRule.once) {
        final base = r.baseNext(snooze.isAfter(now) ? snooze : now);
        if (base != null) requests.add(r.copy(at: base, clearSnooze: true));
      }
    } else if (r.baseNext(now) != null) {
      requests.add(r);
    }
  }
  requests.sort((a, b) => a.next(now)!.compareTo(b.next(now)!));
  return requests.take(48).toList();
}

// Inexact OS alarms can legitimately remain queued after their requested time.
// Reopening the desk must not cancel that queued occurrence as merely "past".
// This only retains an existing matching request, never schedules a past one.
bool retainOverdueRequest(
  Reminder reminder,
  int requestId,
  String? payload,
  String? title,
  DateTime now,
) {
  if (!reminder.enabled || title != reminder.title) return false;
  final due = requestId == 1000000000 + reminder.id
      ? reminder.snoozedUntil
      : requestId == reminder.id &&
            reminder.repeat == RepeatRule.once &&
            reminder.snoozedUntil == null
      ? reminder.at
      : null;
  if (due == null ||
      due.isAfter(now) ||
      now.difference(due) > const Duration(days: 1)) {
    return false;
  }
  try {
    final data = jsonDecode(payload ?? '');
    return data is Map &&
        data['kind'] == 'task' &&
        data['entry'] == reminder.entryId;
  } catch (_) {
    return false;
  }
}

abstract class ReminderGateway {
  bool get permitted;
  String get status;
  Future<void> initialize(void Function(String?) onTap);
  Future<bool> requestPermission();
  Future<void> reconcile(List<Reminder> reminders);
  Set<int> get scheduled;
}

class LocalNotifications implements ReminderGateway {
  final plugin = FlutterLocalNotificationsPlugin();
  @override
  bool permitted = false;
  @override
  String status = 'Notifications are off. Reminders are saved locally.';
  @override
  Set<int> scheduled = {};
  final Map<int, String> _fingerprints = {};
  String _zone = '';
  bool get supported => Platform.isAndroid || Platform.isIOS;
  @override
  Future<void> initialize(void Function(String?) onTap) async {
    if (!supported) {
      status = 'OS reminders are available on Android and iOS.';
      return;
    }
    zones.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload),
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      onTap(launch?.notificationResponse?.payload);
    }
    await _permission();
  }

  Future<void> _permission() async {
    if (Platform.isAndroid) {
      permitted =
          await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      permitted =
          (await plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    status = permitted
        ? 'Notifications enabled · delivery time may vary'
        : 'Notifications are off. Enable them in system settings.';
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    if (Platform.isIOS) {
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    await _permission();
    return permitted;
  }

  @override
  Future<void> reconcile(List<Reminder> reminders) async {
    if (!supported) return;
    await _permission();
    // Refresh device timezone on every resume or mutation. Never fall back to UTC.
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(zone));
    if (zone != _zone) {
      _fingerprints.clear();
      _zone = zone;
    }
    final now = DateTime.now();
    // A snooze is a separate one-shot request. Recurrence retains its original
    // wall-clock anchor and resumes strictly after the snoozed occurrence.
    final upcoming = planReminderRequests(reminders, now);
    // 48 slots leaves headroom below iOS's 64 pending notification limit.
    final pending = await plugin.pendingNotificationRequests();
    final retained = permitted
        ? pending
              .where(
                (p) => reminders.any(
                  (r) => retainOverdueRequest(r, p.id, p.payload, p.title, now),
                ),
              )
              .map((p) => p.id)
              .toSet()
        : <int>{};
    final desired = permitted
        ? upcoming.take(48 - retained.length.clamp(0, 48)).toList()
        : <Reminder>[];
    final ids = {...desired.map((r) => r.id), ...retained};
    for (final old in pending) {
      if (!ids.contains(old.id)) {
        await plugin.cancel(id: old.id);
        _fingerprints.remove(old.id);
      }
    }
    final pendingIds = pending.map((n) => n.id).toSet();
    scheduled = retained
        .map((id) => id >= 1000000000 ? id - 1000000000 : id)
        .toSet();
    for (final r in desired) {
      final at = r.next(now)!;
      final source = reminders.firstWhere(
        (source) => source.entryId == r.entryId,
      );
      final key = '${jsonEncode(source.toJson())}|${r.id}|$zone';
      if (_fingerprints[r.id] != key || !pendingIds.contains(r.id)) {
        final target = tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          at.hour,
          at.minute,
          at.second,
          at.millisecond,
        );
        if (target.year != at.year ||
            target.month != at.month ||
            target.day != at.day ||
            target.hour != at.hour ||
            target.minute != at.minute) {
          status =
              'A reminder falls in a daylight-saving clock gap. Edit its time.';
          continue;
        }
        await plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: 'A little nudge from Atelier',
          scheduledDate: target,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'atelier_tasks_v1',
              'Task reminders',
              icon: 'ic_notification',
              channelDescription:
                  'Reminders you attach to your own notes and cards',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'kind': 'task', 'entry': r.entryId}),
          matchDateTimeComponents: switch (r.repeat) {
            RepeatRule.once => null,
            RepeatRule.daily => DateTimeComponents.time,
            RepeatRule.weekly => DateTimeComponents.dayOfWeekAndTime,
          },
        );
        _fingerprints[r.id] = key;
      }
      scheduled.add(r.id >= 1000000000 ? r.id - 1000000000 : r.id);
    }
    if (permitted && reminders.where((r) => r.next(now) != null).length > 48) {
      status =
          'Next 48 reminders scheduled. Open Atelier to replenish the queue.';
    }
  }
}

class MemoryNotifications implements ReminderGateway {
  @override
  bool permitted = true;
  @override
  String status = 'Test notification gateway';
  @override
  Set<int> scheduled = {};
  int updates = 0;
  @override
  Future<void> initialize(void Function(String?) onTap) async {}
  @override
  Future<bool> requestPermission() async => permitted;
  @override
  Future<void> reconcile(List<Reminder> reminders) async {
    updates++;
    scheduled = reminders
        .where((r) => permitted && r.next(DateTime.now()) != null)
        .map((r) => r.id)
        .toSet();
  }
}
