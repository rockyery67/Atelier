import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

class LocalStore {
  final Database db;
  LocalStore(this.db);
  static Future<LocalStore> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    if (factory == null && Platform.isWindows) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    final location =
        path ??
        p.join((await getApplicationSupportDirectory()).path, 'atelier.sqlite');
    final database = await (factory ?? databaseFactory).openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE decks (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE entries (id TEXT PRIMARY KEY, deck_id TEXT NOT NULL REFERENCES decks(id), data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE reviews (id TEXT PRIMARY KEY, entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE reminders (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id TEXT NOT NULL UNIQUE REFERENCES entries(id) ON DELETE CASCADE, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE preferences (id INTEGER PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute('CREATE INDEX entries_deck ON entries(deck_id)');
          await db.execute('CREATE INDEX reviews_entry ON reviews(entry_id)');
        },
      ),
    );
    return LocalStore(database);
  }

  Future<Snapshot> read() async {
    // A consistent read snapshot, including concurrent review/deletion writes.
    return db.transaction(
      (tx) async => Snapshot(
        decks: (await tx.query('decks'))
            .map((r) => Deck.fromJson(decodeRow(r)))
            .toList(),
        entries: (await tx.query('entries'))
            .map((r) => Entry.fromJson(decodeRow(r)))
            .toList(),
        reviews: (await tx.query('reviews'))
            .map((r) => Review.fromJson(decodeRow(r)))
            .toList(),
        reminders: (await tx.query('reminders'))
            .map((r) => Reminder.fromJson({...decodeRow(r), 'id': r['id']}))
            .toList(),
        preferences: await _prefs(tx),
      ),
    );
  }

  Future<Preferences> _prefs(DatabaseExecutor tx) async {
    final rows = await tx.query('preferences');
    return rows.isEmpty
        ? const Preferences()
        : Preferences.fromJson(decodeRow(rows.first));
  }

  Future<void> savePreferences(Preferences prefs) => db.insert('preferences', {
    'id': 1,
    'data': jsonEncode(prefs.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> saveDeck(Deck deck) async {
    await db.rawInsert(
      'INSERT INTO decks(id,data) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data',
      [deck.id, jsonEncode(deck.toJson())],
    );
  }

  Future<void> _entry(DatabaseExecutor tx, Entry e) async {
    await tx.rawInsert(
      'INSERT INTO entries(id,deck_id,data) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET deck_id=excluded.deck_id,data=excluded.data',
      [e.id, e.deckId, jsonEncode(e.toJson())],
    );
  }

  Future<void> _reminder(DatabaseExecutor tx, Reminder r) async {
    if (r.id == 0) {
      await tx.rawInsert(
        'INSERT INTO reminders(entry_id,data) VALUES(?,?) ON CONFLICT(entry_id) DO UPDATE SET data=excluded.data',
        [r.entryId, jsonEncode(r.toJson())],
      );
    } else {
      await tx.rawInsert(
        'INSERT INTO reminders(id,entry_id,data) VALUES(?,?,?) ON CONFLICT(entry_id) DO UPDATE SET data=excluded.data',
        [r.id, r.entryId, jsonEncode(r.toJson())],
      );
    }
  }

  Future<void> saveEntry(
    Entry entry, {
    Reminder? reminder,
    bool replaceReminder = false,
  }) => db.transaction((tx) async {
    await _entry(tx, entry);
    if (replaceReminder) {
      await tx.delete(
        'reminders',
        where: 'entry_id = ?',
        whereArgs: [entry.id],
      );
    }
    if (reminder != null) {
      await _reminder(tx, reminder);
    }
  });
  Future<void> saveReminder(Reminder reminder) =>
      db.transaction((tx) => _reminder(tx, reminder));
  Future<void> removeReminder(int id) async {
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> review(Entry entry, Review review) => db.transaction((tx) async {
    await _entry(tx, entry);
    await tx.insert('reviews', {
      'id': review.id,
      'entry_id': review.entryId,
      'data': jsonEncode(review.toJson()),
    });
  });
  Future<DeletedBundle?> deleteEntry(String id) => db.transaction((tx) async {
    final rows = await tx.query('entries', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final reviews = (await tx.query(
      'reviews',
      where: 'entry_id = ?',
      whereArgs: [id],
    )).map((r) => Review.fromJson(decodeRow(r))).toList();
    final reminders = await tx.query(
      'reminders',
      where: 'entry_id = ?',
      whereArgs: [id],
    );
    final bundle = DeletedBundle(
      Entry.fromJson(decodeRow(rows.single)),
      reviews,
      reminders.isEmpty
          ? null
          : Reminder.fromJson({
              ...decodeRow(reminders.single),
              'id': reminders.single['id'],
            }),
    );
    await tx.delete('entries', where: 'id = ?', whereArgs: [id]);
    return bundle;
  });
  Future<void> restore(DeletedBundle bundle, DateTime now) => db.transaction((
    tx,
  ) async {
    await _entry(tx, bundle.entry);
    for (final r in bundle.reviews) {
      await tx.insert('reviews', {
        'id': r.id,
        'entry_id': r.entryId,
        'data': jsonEncode(r.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final r = bundle.reminder;
    if (r != null) {
      // Undo never fires an expired alert. Even recurring reminders are restored
      // disabled if the saved occurrence expired; user explicitly re-enables.
      await _reminder(
        tx,
        r.copy(enabled: r.enabled && (r.snoozedUntil ?? r.at).isAfter(now)),
      );
    }
  });
  Future<void> seed() async {
    if ((await db.query('decks', limit: 1)).isNotEmpty) return;
    final now = DateTime.now();
    const decks = [
      Deck(
        id: 'cs',
        title: 'Computer Science: Data Structures',
        category: 'Engineering',
        description: 'Core algorithms, tree traversals, memory stacks, heaps, and Big-O notation for quieter study sessions.',
      ),
      Deck(
        id: 'spanish',
        title: 'Everyday Spanish (B2)',
        category: 'Languages',
        description:
            'Subjunctive triggers, colloquial idioms & verb aspect pairs',
        style: PaperStyle.sticky,
        tint: 1,
      ),
      Deck(
        id: 'biology',
        title: 'Cellular Biology',
        category: 'Medicine & Life Sci',
        description: 'Small discoveries, from mitochondria to the living cell.',
        tint: 2,
      ),
      Deck(
        id: 'art',
        title: 'Art History: Impressionism',
        category: 'Fine Arts',
        description: 'Monet, Degas, and the art of seeing light.',
        tint: 3,
        style: PaperStyle.sticky,
      ),
    ];
    for (final d in decks) {
      await saveDeck(d);
    }
    final samples = [
      (
        'cs',
        'What principle does a call stack follow?',
        'LIFO (Last In, First Out)',
        'Think of a pile of trays or cafeteria plates.',
      ),
      (
        'cs',
        'Key architectural difference between BFS and DFS traversal?',
        'BFS uses a queue (FIFO). DFS uses a stack (LIFO) or recursion.',
        'Breadth explores neighbours; depth follows a branch.',
      ),
      (
        'cs',
        'Worst-case time complexity of Quicksort?',
        'O(n²) when pivot selection is unbalanced.',
        'Balanced partitions average O(n log n).',
      ),
      (
        'spanish',
        'What does «ojalá» express?',
        'A hope or wish. It is followed by the subjunctive.',
        'Ojalá que tengas un buen día.',
      ),
      (
        'biology',
        'Where does most ATP production happen?',
        'In the mitochondria, through oxidative phosphorylation.',
        'The inner membrane hosts ATP synthase.',
      ),
      (
        'art',
        'What is plein-air painting?',
        'Painting outdoors, directly observing natural light.',
        'Think of Monet’s changing light.',
      ),
    ];
    var index = 0;
    for (final s in samples) {
      await saveEntry(
        Entry(
          id: 'sample-${index++}',
          deckId: s.$1,
          front: s.$2,
          back: s.$3,
          hint: s.$4,
          tint: (index - 1) % 4,
          style: index.isOdd ? PaperStyle.sticky : PaperStyle.pinned,
          due: now,
          created: now,
          tags: [s.$1 == 'cs' ? 'Fundamentals' : 'Discovery'],
        ),
      );
    }
    await saveEntry(
      Entry(
        id: 'welcome-note',
        deckId: 'cs',
        front: 'A little space for your own thoughts.',
        hint: 'Personal notes live alongside your flashcards. Pin a thought, add a photograph, or set a reminder.',
        note: true,
        tint: 1,
        style: PaperStyle.sticky,
        due: now,
        created: now,
        tags: const ['Journal'],
      ),
    );
  }
}
