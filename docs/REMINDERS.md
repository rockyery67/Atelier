# Local reminders and platform configuration

The parser and scheduler are local. There is no account, server, network NLP or
background Dart timer responsible for delivering alerts. Note text is preserved.

## Supported English task grammar

Examples accepted:

- `Submit assignment at 4 pm`
- `Submit assignment on 2026/10/29 at 4 pm`
- `[Submit assignment] at [4 pm]/[2026/10/29]`
- `Call Alex tomorrow at 10 am`
- `Remind Me: Submit assignment — 2026/10/29, 4 pm`
- `Buy notebooks on 2026-10-29` (requires a configured default time or manual time)

Dates must be year-first `YYYY/MM/DD` or `YYYY-MM-DD`; times are 12-hour am/pm,
with optional minutes, e.g. `4:30 pm`. `today` and `tomorrow` are supported.
Without `Remind Me:`, a conservative task verb is required: submit, call, buy,
send, pay, finish, complete, attend, meet, email, take, pick up, return, book,
renew, review, read, write, bring, water, visit. The scheduling expression must
end the text. Freeform task titles work after the explicit `Remind Me:` prefix.

Questions, quoted text, examples and ordinary educational statements are ignored.
Multiple dates/times, invalid calendar dates, day/month/year dates, weekdays,
`next ...`, `noon`, `midnight`, timezone names and offsets require clarification.
Unsupported text never silently creates an alert. Single-quoted whole examples
are not task-verb prefixes and are ignored. Natural language outside this grammar
can always use the dedicated date/time pickers.

The editor shows a detected-reminder panel with the resolved **day and time**,
an inspect/edit action and a dismiss control. On save, an eligible detection is
stored transactionally with the note. With permission, it is OS-scheduled; without
permission, the summary says it was saved, not scheduled. Grant permission from
the reminder sheet or reminder list. The OS prompt is never shown at startup.
The save confirmation includes both Edit and Undo reminder actions; Undo affects
only the reminder, leaving the original text intact.

Time-only expressions use the next occurrence, including tomorrow if today's
time passed. Explicit past dates and times are rejected. Date-only expressions
use Settings > Default reminder time; if unset, the chip asks for a time. Manual
pickers support once, daily and weekly schedules. A 10-minute snooze uses a
separate stable one-shot OS identifier while preserving the daily/weekly anchor.
Disable/delete cancels both ordinary and snoozed pending requests.

## Identity, reconciliation, routing and deletion

- One task reminder per entry, enforced by a UNIQUE SQL constraint. Integer IDs
  are monotonic and persist across edits; duplicate saves update the same row.
- Snooze request ID = 1,000,000,000 + reminder ID, separate from the repeating
  request. The notification payload is `{kind: task, entry: <UUID>}`.
- Startup, foreground resume and each mutation reconcile stored future reminders
  with OS pending requests. Stale/disabled/deleted requests are cancelled; changed
  requests replace the same ID. Fingerprints avoid needless rescheduling.
- Already queued one-shot alerts that are late under inexact OS scheduling are
  retained for up to 24 hours if their entry, title and enabled state still match.
  Resume does not turn a late alert into an accidental cancellation. This retains
  an existing OS request; it never creates or re-schedules a past notification.
- Taps validate payload kind and entry existence. Foreground taps and cold-launch
  details go through the same routing function and open the actual card/note.
- Note edits reschedule its detected reminder. Removing/dismissing a detected
  expression removes its automatic reminder; manual reminders remain explicit.
- Entry deletion cascades reminder/history records in the same SQL transaction.
  Cancellation is retried through reconciliation if the OS operation fails; a
  visible scheduling error explains this state. Destruction starts only after
  successful SQL deletion.
- Undo restores IDs, history, deck, image and reminder. If the saved occurrence
  (or snoozed occurrence) expired during the Undo interval, the restored reminder
  is disabled. It never schedules a catch-up alert; edit/re-enable explicitly.
- Task reminders are separate from spaced-review due dates. Automatic study
  notifications are deliberately absent, so the same task has no study duplicate.

## Android

`flutter_local_notifications` is pinned to **22.3.2**. Compile SDK 36, Java 17
compatibility and desugar_jdk_libs 2.1.4 are configured. The manifest includes
POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED, the scheduled receiver and the
Atelier clock receiver. The monochrome notification icon is bundled locally.

Android 13+ runtime permission is requested contextually. Scheduling uses
`inexactAllowWhileIdle`, avoiding special exact-alarm access for this notes app.
It does not request USE_EXACT_ALARM, bypass DND, acquire a wake lock for reminders
or exempt itself from battery optimization. Doze, standby, OEM restrictions and
user channel settings can delay or suppress alerts. Force-stopping an Android
app prevents alarms until the user launches it again; process death and swiping
away are different from force-stop.

AtelierClockReceiver rebases pending wall-clock requests on BOOT_COMPLETED,
MY_PACKAGE_REPLACED, TIMEZONE_CHANGED and TIME_SET, dropping expired one-shots
and daylight-saving gap times before reusing the plugin scheduler. It accesses
the **version-pinned** plugin cache schema; update this adapter and retest it
when upgrading the plugin. The Dart reconciler refreshes the IANA timezone on
resume as an additional check. The app never silently falls back to UTC.

Official requirements checked during implementation:

- [Android notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [Android alarm scheduling and timing restrictions](https://developer.android.com/develop/background-work/services/alarms)
- [Plugin configuration and limitations](https://pub.dev/packages/flutter_local_notifications)

## iOS

The runner sets UNUserNotificationCenter's delegate; initialization suppresses
startup permission prompts. The reminder UI requests alert/sound/badge access.
No background execution mode or remote push entitlement is needed for local
calendar notifications. System notification settings, Focus and Scheduled
Summary still affect presentation. The OS handles delivery when the app is closed.

The scheduler uses the device's IANA timezone and validates resolved wall times.
Daily/weekly recurrence uses calendar components. Reconciliation is performed
when the app resumes, including after device timezone changes. iOS itself
persists scheduled notification requests; no Android-style boot receiver exists.

At most **48 OS requests** are queued, below the plugin-documented iOS limit of
64. Snoozes count against this budget. Remaining records stay in SQLite; the
reminder screen explains that opening Atelier replenishes the queue. Unlimited
future delivery without reopening is not promised. Android uses the same bounded
queue, below reported vendor alarm limits.

- [Apple local notification scheduling and cancellation](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

Windows supports the local desk, editing and study. OS reminder scheduling in
this app is explicitly mobile-only; the UI states that limitation. iOS source
configuration is included, but building and physical iOS testing require macOS,
Xcode and a signing team. No exact-delivery guarantee is made on any platform.
