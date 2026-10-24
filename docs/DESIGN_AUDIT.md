# Atelier: design audit and implementation decisions

The starting workspace contained four Stitch screen exports and no application,
AGENTS.md, or existing implementation to preserve. All four screen.png images and
their code.html files were inspected before the data model and Flutter UI were
written. The untouched exports are in `stitch_warm_notes_flashcards/`.

| Reference | Visual structure retained | Working behavior |
| --- | --- | --- |
| atelier_home_dashboard | Ivory desk, editorial greeting, tilted pinned priority card, inset prompt, daily ledger, action pills, pastel archival decks, four-tab navigation | Actual due counts, progress from review history, new deck/card/note, shuffle due, appearance filter |
| atelier_deck_details | Pinned deck heading, three metrics, dark study pill, search/filter chips, paper card list, configuration panel | Search prompts/answers/tags/notes, due/bookmark/difficult/note filters, practice and due sessions, deck editing |
| atelier_create_flashcard | Deck selector, front/back control, desk preview, pin/tape choices, five paper tints, penmanship, ruled editor, image attachment | Native text entry, live preview, real local attachments, conservative reminder chip, full persistence |
| atelier_interactive_study_session | Editorial title, progress rule, dotted paper, prompt/answer, four pastel ratings, quiet bottom tools | Perspective flip, reveal-gated ratings, durable review scheduling, completion, bookmark/edit/finish later |

## Tokens and composition

- Desk: #FBF9F5; charcoal ink: #2C2825; inset panel: #EFEEEA.
- Stock: ivory #E8E1D1, peach #EED1C4, sage #CADBC0, lavender #D6CCE4,
  white paper #F5F2EB. Terracotta #BD684D is a restrained accent.
- Local Newsreader headings, Caveat handwriting, Plus Jakarta Sans controls and
  clean print. Card text can be resized independently and also respects OS scale.
- 20 px phone page gutters, 16–24 px internal spacing, 28 px paper corners,
  restrained downward shadows, brass gradient pin and matte tape drawn in Flutter.
- Dark mode uses a charcoal-green desk, tinted muted paper, warm light ink and
  brighter secondary text. No paper photograph is used as a screen/background.
- Paper is real selectable/editable application content, never a screenshot or
  WebView. The profile avatar is replaced by a functional reminder control; no
  fictional user identity, progress, or fake study counts are displayed.
- The editor moves the native writing area just below its preview, keeping it
  reachable before appearance controls. Small layouts scroll; forms retain their
  controllers and selection. Study paper has a bounded independently scrolling
  content area so ratings remain accessible.
- The reference's FSRS label is replaced by **Atelier spaced review**. The app
  implements a transparent interval scheduler, not FSRS.

## Local data model

SQLite schema v1, foreign keys enabled. Every row stores an explicit typed JSON
payload plus indexed relationship columns. Mutations use upsert rather than
SQLite REPLACE on parent rows, avoiding accidental foreign-key cascades.

| Table | Identity / relationships | Stored information |
| --- | --- | --- |
| decks | UUID text primary key | Title, description, category, default paper style/tint, separate pin-to-top |
| entries | UUID primary key, deck_id foreign key/index | Flashcard or single-sided note; original front/back/hint; tags; bookmark; pin-to-top; paper style/tint; font/size; private image path; due/created dates; interval/repetitions |
| reviews | UUID primary key, entry_id cascade/index | Rating, timestamp, resulting interval |
| reminders | Monotonic integer primary key; unique entry_id cascade | Task title, device-local wall date/time, once/daily/weekly, enabled, automatic/manual origin, optional snooze |
| preferences | Singleton | Theme, motion, deletion effect, sound/volume/writing sound, clean print/text scale, default reminder time, daily goal, onboarding |

Database work uses the plugin's background database facilities. Desktop uses
sqflite FFI. Mutations are serialized in the controller to avoid lost preference
patches and racing reminder operations. Images are resized by the platform picker
and copied into private application storage before their reference is committed.

Entry + detected-reminder updates and entry + review updates are transactional.
Deletion snapshots the entry, all reviews, and associated reminder in one SQL
transaction. Foreign-key cascade removes relationships. Undo restores original
identities, deck association, image reference, tags, bookmark, review history and
reminder. A reminder whose saved occurrence has expired is restored disabled.

The sample library is small and editable: four decks, six real study cards and
one personal note. It exists only on first database creation. No inflated counts.

## Motion and sound boundaries

Motion durations are centralized in the context policy, with system reduced
motion taking precedence over user mode. Full mode uses short perspective flips,
paper transitions and twelve strips; reduced uses five strips and shorter fades;
minimal removes decorative transformations and uses a short deletion fade.
No idle ticker, continuous particles, blur filter or heavyweight physics engine.

Only `Deletion.perform` can create a destruction overlay: explicit confirmation,
capture the actual render boundary, commit SQL deletion, create a temporary
image overlay, play the corresponding deletion sound, dispose image/overlay on
completion. Failure/cancel never reaches that entry point. Requests are guarded
by entry ID; a second storage deletion returns no bundle and cannot play again.

The pen nib uses the real RenderEditable caret rectangle, a short rotation, and a
timer. It does not write to the text, caret, composing range or selection. Bulk
insertions get a brief acknowledgment, not letter playback. Selection and IME
composition hide the decoration. Fonts do not contain stroke-by-stroke data.

Audio uses two reusable players, three preloaded frequent clips, asset caching,
per-effect throttling and no queue buildup. Android ringer/DND checks suppress
effects; iOS ambient audio obeys silent mode. No forced volume or audio focus.
