# Verification record

Date: 23 October 2026, Asia/Katmandu. Evidence distinguishes host checks,
physical-device checks and platform configuration that has not been run.

## Host verification

- Flutter 3.47.0, Dart 3.13.0, Windows host.
- Dart formatting, Flutter analyzer: clean.
- **46 tests pass** using SQLite FFI and Flutter's widget test runner.
- Persistence/reopen; review history and interval scheduling; conservative parser
  patterns, ambiguous/past dates and unsupported timezone suffixes; reminder
  identity, edit/cancel/deduplication; denied permission/reconciliation; notification
  payload routing; SQL deletion failure rollback; duplicate deletion guards;
  complete Undo relationships and expired reminder restoration; serialized settings;
  bounded notification planning and once/repeat snooze behavior.
- An additional late-alarm test verifies that a matching queued inexact request
  survives resume without scheduling any new past alert.
- Widget checks cover light/dark layouts, 320×640 with keyboard insets and long
  content, native selection/composition/paste preservation, reveal-gated rating
  persistence, deletion cancellation/failure/success/Undo, and retained tab search.
- `docs/screenshots/` contains 390×844 host renders with bundled fonts. Physical
  screenshots in `docs/device/` were also inspected against all four Stitch
  references. Visible corrections included the hero footer wrapping and oversized
  study paper that initially pushed ratings below the first viewport.

## Physical Android workflow

Device reports model **2201117TG**, chipset **SM6225**, Android 17/API 37,
1080×2400, density 440, native display mode 90 Hz. It is a physical Android phone,
not an emulator. It was charging; this was not a thermal/battery endurance test.

The profile integration journey passed:

- Open actual local app database; edit and save a personal note while a keyboard
  is present; retain selection and original note text; detect/store its reminder.
- Open deck details, reveal front/back, rate a card and persist session completion.
- Full/Reduced/Minimal study and scrolling samples.
- Light and dark paper, Sticky note, pin/tape rendering, cancellation of deletion,
  successful Shred and Crumple, Undo restoring note and reminder.
- Contextual OS notification permission granted from the reminder screen.
- All fixture state persisted locally; normal release installed over the fixture
  without deleting its database, exercising package-replacement rescheduling.

The integration input fixture sets the editing controller to represent a paste;
host widget tests separately exercise TextInput and composing/selection ranges.
It does not establish acceptance for every physical keyboard, dictation engine,
language or IME. Screenshots captured through integration_test include the Flutter
view; they exclude the OS keyboard pixels.

## Frame timing sample

`docs/device/integration.json` records the final physical profile sample. Each
mode opened a two-card study session, flipped and rated both cards, then scrolled
the home list. The expensive screenshot ImageView was reverted to the GPU surface
before timing. Screenshot capture, startup and the temporary device-lock wait were
outside these per-mode sample intervals.

| Mode | Frames | Build p95 | Raster p95 | Build max | Raster max | Frames with build or raster >16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full | 149 | 8.292 ms | 18.863 ms | 40.840 ms | 45.445 ms | 16 |
| Reduced | 143 | 9.027 ms | 14.022 ms | 40.048 ms | 21.296 ms | 6 |
| Minimal | 142 | 6.886 ms | 8.019 ms | 56.226 ms | 15.706 ms | 4 |

These are short workflow measurements, not universal FPS claims. A 90 Hz display
has an 11.11 ms frame budget; the last column uses a 60 Hz/16.67 ms comparison
threshold. Full mode still shows raster jank. Reduced and especially Minimal
lower raster costs, but all modes have occasional build spikes. Use Minimal for
this device when frame consistency matters. Long libraries, very large images,
thermal throttling, physical audio latency and long study sessions remain outside
this sample. The app's image cache is capped at 32 MiB/70 entries, lists are lazy,
and there are no idle decoration tickers.

## Notification delivery evidence

The fixture queues actual Android OS alarms in the device timezone, without a
backend. The scheduling mode is inexact; the system's alarm windows are visible
in dumpsys. Probe results are recorded in `docs/device/notification-delivery.json`.

The background probe was requested for **16:47:39**. The notification was posted
at approximately **16:49:08.656**, while the launcher was foreground and Atelier's
process was still alive: about **89 seconds late**, within the system-selected
inexact window. This directly demonstrates why exact-minute delivery is not
promised.

The first release-only closed-process probe exposed a missing small icon after
Android resource shrinking. `res/raw/keep.xml` now retains that drawable; the
release APK's resource table was checked with aapt2. The closed-process retest
uses the normal release app and a new requested time of **16:56:00**. The process
was verified absent, with `stopped=false` (no force-stop), before that request.
See `closed-process-precondition.txt` and the delivery evidence JSON.

The retest posted at **16:57:13.410**, about **73 seconds late**, while the app's
process had been absent. The receiver started a native process to post it. That
process was killed again before tapping the notification: the tap then cold-started
the normal Flutter release and opened the correct personal note, **Closed-process
reminder acceptance probe**. `cold-tap-routing.txt` and `cold-start-note.png`
record that result. The release resource fix therefore passed the previously
failing closed-process path.

The normal release was also edited through Android's actual keyboard using key
events. The typed suffix `Ink` appeared immediately, the small pen nib was visible
next to the native caret, and long-press selection exposed native handles and the
selection toolbar with the pen hidden. The text then saved without loss. See
`native-writing-keyboard.png` and `native-selection.png`. Host tests additionally
cover paste and IME composing ranges. This remains a bounded single-device check.

The final universal release APK builds successfully and its merged manifest has
no INTERNET permission. It uses the development signing key for local testing;
store signing and physical iOS acceptance remain separate work.

All three device-test notes and their reminders were removed after verification;
the reminder list is empty and no future Atelier task alarm remains. The phone's
original keep-awake setting (0) was restored. The read-only emulator was stopped.

## Assets and platform limits

All 11 WAV clips have nonzero samples and bounded durations of 0.12–0.82 seconds.
Real foley source licenses and hashes are saved with the project. Playback uses
two reusable players and cached clips. The phone's quiet-mode behavior is
respected; no device volume or quiet setting was changed for audition. Subjective
foley quality, audible synchronization and iOS silent-switch behavior still need
human audition on the intended hardware.

iOS has not been compiled or run: this host is Windows. Its delegate, local
notification initialization and photo-library description are configured, with
current official guidance linked in REMINDERS.md. Reboot and actual timezone/DST
changes have not been performed on the user's phone. Android clock receiver and
iOS calendar behavior need those platform acceptance checks; no reboot or exact
delivery guarantee is claimed. The temporarily started read-only emulator was
stopped once physical testing resumed; it supplied no acceptance results.
