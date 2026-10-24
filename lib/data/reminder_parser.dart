enum DetectionState { none, ready, needsTime, clarify, past }

class Detection {
  final DetectionState state;
  final String title, message;
  final DateTime? at;
  const Detection(this.state, {this.title = '', this.message = '', this.at});
}

/// Deliberately conservative, English-only task grammar. Never parses questions,
/// quoted examples, multiple dates/times, or numeric dates outside YYYY/MM/DD.
class ReminderParser {
  static final _date = RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b');
  static final _time = RegExp(
    r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    caseSensitive: false,
  );
  static Detection parse(String source, DateTime now, {int? defaultMinutes}) {
    var text = source.trim();
    if (text.isEmpty ||
        text.contains('?') ||
        RegExp('[“”"`]').hasMatch(text) ||
        RegExp(
          r'^(example|e\.g\.|what|when|why|how|who|explain|define)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      return const Detection(DetectionState.none);
    }
    final explicit = RegExp(r'^remind\s+me\s*[:—-]?\s*', caseSensitive: false);
    final isExplicit = explicit.hasMatch(text);
    text = text.replaceFirst(explicit, '').replaceAll(RegExp(r'[\[\]]'), '');
    final task = RegExp(
      r'^(submit|call|buy|send|pay|finish|complete|attend|meet|email|take|pick up|return|book|renew|review|read|write|bring|water|visit)\b',
      caseSensitive: false,
    ).hasMatch(text);
    if (!isExplicit && !task) return const Detection(DetectionState.none);
    final dates = _date.allMatches(text).toList(),
        times = _time.allMatches(text).toList();
    final relative = RegExp(
      r'\b(today|tomorrow)\b',
      caseSensitive: false,
    ).allMatches(text).toList();
    // The supported scheduling expression must be a suffix. Do not silently
    // interpret timezone names, offsets, ranges or explanatory trailing prose.
    final expressionEnd = [
      ...dates,
      ...times,
      ...relative,
    ].fold<int>(0, (end, m) => m.end > end ? m.end : end);
    final tail = text.substring(expressionEnd).trim();
    if (expressionEnd > 0 &&
        tail.isNotEmpty &&
        !RegExp(r'^[.,/\s]*$').hasMatch(tail)) {
      return const Detection(
        DetectionState.clarify,
        message: 'This expression needs clarification. Choose a local date and time.',
      );
    }
    if (RegExp(
      r'\b(utc|gmt|pst|est|cet)\b|[+-]\d{2}:\d{2}|\b\d{1,2}/\d{1,2}\b',
      caseSensitive: false,
    ).hasMatch(text.replaceAll(_date, ''))) {
      return const Detection(
        DetectionState.clarify,
        message: 'Choose a date and time in your device’s local timezone.',
      );
    }
    if (dates.length > 1 ||
        times.length > 1 ||
        relative.length > 1 ||
        (dates.isNotEmpty && relative.isNotEmpty) ||
        RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b').hasMatch(text) ||
        RegExp(
          r'\b(next|tonight|noon|midnight|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      return const Detection(
        DetectionState.clarify,
        message: 'Choose a date and time. This expression is ambiguous or unsupported.',
      );
    }
    if (dates.isEmpty && times.isEmpty && relative.isEmpty) {
      return isExplicit
          ? const Detection(
              DetectionState.clarify,
              message: 'Choose a date and time for this reminder.',
            )
          : const Detection(DetectionState.none);
    }
    if (RegExp(r'\b\d{1,2}:\d{2}\b').allMatches(text).length > times.length) {
      return const Detection(
        DetectionState.clarify,
        message: 'Use am/pm, or choose the time manually.',
      );
    }
    var day = DateTime(now.year, now.month, now.day);
    if (dates.isNotEmpty) {
      final d = dates.single;
      final y = int.parse(d[1]!), m = int.parse(d[2]!), v = int.parse(d[3]!);
      day = DateTime(y, m, v);
      if (day.year != y || day.month != m || day.day != v) {
        return const Detection(
          DetectionState.clarify,
          message: 'That calendar date is invalid.',
        );
      }
    } else if (relative.isNotEmpty &&
        relative.single[1]!.toLowerCase() == 'tomorrow') {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    int hour, minute;
    if (times.isEmpty) {
      if (defaultMinutes == null) {
        return const Detection(
          DetectionState.needsTime,
          message: 'A date was detected. Choose a time.',
        );
      }
      hour = defaultMinutes ~/ 60;
      minute = defaultMinutes % 60;
    } else {
      final t = times.single;
      hour = int.parse(t[1]!);
      minute = int.parse(t[2] ?? '0');
      if (hour < 1 || hour > 12 || minute > 59) {
        return const Detection(
          DetectionState.clarify,
          message: 'That time is invalid.',
        );
      }
      hour = hour % 12 + (t[3]!.toLowerCase() == 'pm' ? 12 : 0);
    }
    var at = DateTime(day.year, day.month, day.day, hour, minute);
    if (!at.isAfter(now)) {
      if (dates.isEmpty && relative.isEmpty) {
        at = DateTime(day.year, day.month, day.day + 1, hour, minute);
      } else {
        return const Detection(
          DetectionState.past,
          message: 'This time has passed. Choose a future date and time.',
        );
      }
    }
    var title = text
        .replaceAll(_date, '')
        .replaceAll(_time, '')
        .replaceAll(RegExp(r'\b(today|tomorrow)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(at|on)\b\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[—,/\s-]+$'), '')
        .trim();
    title = title
        .replaceAll(RegExp(r'\s+\b(on|at)\s*$', caseSensitive: false), '')
        .trim();
    if (title.isEmpty) {
      return const Detection(
        DetectionState.clarify,
        message: 'Add a task title.',
      );
    }
    return Detection(
      DetectionState.ready,
      title: title,
      at: at,
      message: 'Reminder detected',
    );
  }
}
