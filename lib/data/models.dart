import 'dart:convert';

typedef Json = Map<String, dynamic>;

enum PaperStyle { pinned, sticky }

enum MotionMode { full, reduced, minimal }

enum DeleteEffect { shred, crumple }

enum Rating { again, hard, good, easy }

enum RepeatRule { once, daily, weekly }

class Deck {
  final String id, title, description, category;
  final int tint;
  final PaperStyle style;
  final bool pinned;
  const Deck({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    this.tint = 0,
    this.style = PaperStyle.pinned,
    this.pinned = false,
  });
  Json toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'tint': tint,
    'style': style.name,
    'pinned': pinned,
  };
  factory Deck.fromJson(Json j) => Deck(
    id: j['id'],
    title: j['title'],
    description: j['description'],
    category: j['category'],
    tint: j['tint'],
    style: PaperStyle.values.byName(j['style']),
    pinned: j['pinned'],
  );
  Deck copy({
    String? title,
    String? description,
    String? category,
    int? tint,
    PaperStyle? style,
    bool? pinned,
  }) => Deck(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    tint: tint ?? this.tint,
    style: style ?? this.style,
    pinned: pinned ?? this.pinned,
  );
}

class Entry {
  final String id, deckId, front, back, hint;
  final bool note, bookmarked, pinned, cleanPrint;
  final PaperStyle style;
  final int tint, repetitions;
  final double textSize, intervalDays;
  final List<String> tags;
  final String? imagePath;
  final DateTime due, created;
  const Entry({
    required this.id,
    required this.deckId,
    required this.front,
    this.back = '',
    this.hint = '',
    this.note = false,
    this.bookmarked = false,
    this.pinned = false,
    this.cleanPrint = false,
    this.style = PaperStyle.pinned,
    this.tint = 0,
    this.repetitions = 0,
    this.textSize = 26,
    this.intervalDays = 0,
    this.tags = const [],
    this.imagePath,
    required this.due,
    required this.created,
  });
  Json toJson() => {
    'id': id,
    'deckId': deckId,
    'front': front,
    'back': back,
    'hint': hint,
    'note': note,
    'bookmarked': bookmarked,
    'pinned': pinned,
    'cleanPrint': cleanPrint,
    'style': style.name,
    'tint': tint,
    'repetitions': repetitions,
    'textSize': textSize,
    'intervalDays': intervalDays,
    'tags': tags,
    'imagePath': imagePath,
    'due': due.toIso8601String(),
    'created': created.toIso8601String(),
  };
  factory Entry.fromJson(Json j) => Entry(
    id: j['id'],
    deckId: j['deckId'],
    front: j['front'],
    back: j['back'],
    hint: j['hint'],
    note: j['note'],
    bookmarked: j['bookmarked'],
    pinned: j['pinned'],
    cleanPrint: j['cleanPrint'],
    style: PaperStyle.values.byName(j['style']),
    tint: j['tint'],
    repetitions: j['repetitions'],
    textSize: (j['textSize'] as num).toDouble(),
    intervalDays: (j['intervalDays'] as num).toDouble(),
    tags: List<String>.from(j['tags']),
    imagePath: j['imagePath'],
    due: DateTime.parse(j['due']),
    created: DateTime.parse(j['created']),
  );
  Entry copy({
    String? front,
    String? back,
    String? hint,
    bool? bookmarked,
    bool? pinned,
    DateTime? due,
    int? repetitions,
    double? intervalDays,
  }) => Entry.fromJson({
    ...toJson(),
    'front': ?front,
    'back': ?back,
    'hint': ?hint,
    'bookmarked': ?bookmarked,
    'pinned': ?pinned,
    if (due != null) 'due': due.toIso8601String(),
    'repetitions': ?repetitions,
    'intervalDays': ?intervalDays,
  });
}

class Review {
  final String id, entryId;
  final Rating rating;
  final DateTime at;
  final double intervalDays;
  const Review({
    required this.id,
    required this.entryId,
    required this.rating,
    required this.at,
    required this.intervalDays,
  });
  Json toJson() => {
    'id': id,
    'entryId': entryId,
    'rating': rating.name,
    'at': at.toIso8601String(),
    'intervalDays': intervalDays,
  };
  factory Review.fromJson(Json j) => Review(
    id: j['id'],
    entryId: j['entryId'],
    rating: Rating.values.byName(j['rating']),
    at: DateTime.parse(j['at']),
    intervalDays: (j['intervalDays'] as num).toDouble(),
  );
}

class Reminder {
  final int id;
  final String entryId, title;
  final DateTime at;
  final DateTime? snoozedUntil;
  final RepeatRule repeat;
  final bool enabled, automatic;
  const Reminder({
    this.id = 0,
    required this.entryId,
    required this.title,
    required this.at,
    this.snoozedUntil,
    this.repeat = RepeatRule.once,
    this.enabled = true,
    this.automatic = false,
  });
  Json toJson() => {
    'id': id,
    'entryId': entryId,
    'title': title,
    'at': at.toIso8601String(),
    'snoozedUntil': snoozedUntil?.toIso8601String(),
    'repeat': repeat.name,
    'enabled': enabled,
    'automatic': automatic,
  };
  factory Reminder.fromJson(Json j) => Reminder(
    id: j['id'],
    entryId: j['entryId'],
    title: j['title'],
    at: DateTime.parse(j['at']),
    snoozedUntil: j['snoozedUntil'] == null
        ? null
        : DateTime.parse(j['snoozedUntil']),
    repeat: RepeatRule.values.byName(j['repeat']),
    enabled: j['enabled'],
    automatic: j['automatic'],
  );
  Reminder copy({
    int? id,
    String? title,
    DateTime? at,
    bool? enabled,
    RepeatRule? repeat,
    bool? automatic,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) => Reminder(
    id: id ?? this.id,
    entryId: entryId,
    title: title ?? this.title,
    at: at ?? this.at,
    repeat: repeat ?? this.repeat,
    enabled: enabled ?? this.enabled,
    automatic: automatic ?? this.automatic,
    snoozedUntil: clearSnooze ? null : snoozedUntil ?? this.snoozedUntil,
  );
  DateTime? next(DateTime now) {
    if (!enabled) return null;
    if (snoozedUntil != null && snoozedUntil!.isAfter(now)) return snoozedUntil;
    if (snoozedUntil != null && repeat == RepeatRule.once) return null;
    return baseNext(now);
  }

  DateTime? baseNext(DateTime now) {
    if (!enabled) return null;
    if (at.isAfter(now)) return at;
    if (repeat == RepeatRule.once) return null;
    // Calendar arithmetic preserves the wall-clock hour through DST changes.
    var value = at;
    final step = repeat == RepeatRule.daily ? 1 : 7;
    final days = now.difference(at).inDays;
    value = DateTime(
      value.year,
      value.month,
      value.day + (days ~/ step) * step,
      value.hour,
      value.minute,
    );
    while (!value.isAfter(now)) {
      value = DateTime(
        value.year,
        value.month,
        value.day + step,
        value.hour,
        value.minute,
      );
    }
    return value;
  }
}

class Preferences {
  final String theme;
  final MotionMode motion;
  final DeleteEffect deleteEffect;
  final bool sound, writingSound, cleanPrint, onboarded;
  final double volume, textScale;
  final int? defaultReminderMinutes;
  final int dailyGoal;
  const Preferences({
    this.theme = 'system',
    this.motion = MotionMode.full,
    this.deleteEffect = DeleteEffect.shred,
    this.sound = true,
    this.writingSound = false,
    this.cleanPrint = false,
    this.onboarded = false,
    this.volume = .35,
    this.textScale = 1,
    this.defaultReminderMinutes,
    this.dailyGoal = 20,
  });
  Json toJson() => {
    'theme': theme,
    'motion': motion.name,
    'deleteEffect': deleteEffect.name,
    'sound': sound,
    'writingSound': writingSound,
    'cleanPrint': cleanPrint,
    'onboarded': onboarded,
    'volume': volume,
    'textScale': textScale,
    'defaultReminderMinutes': defaultReminderMinutes,
    'dailyGoal': dailyGoal,
  };
  factory Preferences.fromJson(Json j) => Preferences(
    theme: j['theme'] ?? 'system',
    motion: MotionMode.values.byName(j['motion'] ?? 'full'),
    deleteEffect: DeleteEffect.values.byName(j['deleteEffect'] ?? 'shred'),
    sound: j['sound'] ?? true,
    writingSound: j['writingSound'] ?? false,
    cleanPrint: j['cleanPrint'] ?? false,
    onboarded: j['onboarded'] ?? false,
    volume: (j['volume'] ?? .35).toDouble(),
    textScale: (j['textScale'] ?? 1).toDouble(),
    defaultReminderMinutes: j['defaultReminderMinutes'],
    dailyGoal: j['dailyGoal'] ?? 20,
  );
  Preferences change(Json patch) =>
      Preferences.fromJson({...toJson(), ...patch});
}

class Snapshot {
  final List<Deck> decks;
  final List<Entry> entries;
  final List<Review> reviews;
  final List<Reminder> reminders;
  final Preferences preferences;
  const Snapshot({
    this.decks = const [],
    this.entries = const [],
    this.reviews = const [],
    this.reminders = const [],
    this.preferences = const Preferences(),
  });
}

class DeletedBundle {
  final Entry entry;
  final List<Review> reviews;
  final Reminder? reminder;
  const DeletedBundle(this.entry, this.reviews, this.reminder);
}

Json decodeRow(Map<String, Object?> row) =>
    jsonDecode(row['data'] as String) as Json;

class ReviewSchedule {
  static double interval(Entry entry, Rating rating) => switch (rating) {
    Rating.again => 1 / 1440,
    Rating.hard => entry.intervalDays < 1 ? .5 : entry.intervalDays * 1.2,
    Rating.good => entry.intervalDays < 1 ? 2 : entry.intervalDays * 2.3,
    Rating.easy => entry.intervalDays < 1 ? 5 : entry.intervalDays * 3.2,
  };
  static Entry apply(Entry entry, Rating rating, DateTime now) {
    final days = interval(entry, rating).clamp(1 / 1440, 365.0);
    return entry.copy(
      due: now.add(Duration(seconds: (days * 86400).round())),
      repetitions: entry.repetitions + 1,
      intervalDays: days,
    );
  }
}
