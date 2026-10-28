import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first gamification and progression engine. No network is required.
class LearningEngine {
  LearningEngine._();
  static final LearningEngine instance = LearningEngine._();

  static const _xpKey = 'lp_engine_total_xp_v1';
  static const _awardedEventsKey = 'lp_engine_awarded_events_v1';
  static const _completedKey = 'lp_engine_completed_lessons_v1';
  static const _goalKey = 'lp_engine_daily_goal_v1';
  static const _dailyXpKey = 'lp_engine_daily_xp_v1';
  static const _lastActiveKey = 'lp_engine_last_active_v1';
  static const _streakKey = 'lp_engine_streak_v1';
  static const _attemptsKey = 'lp_engine_attempts_v1';
  static const _wrongAnswersKey = 'lp_engine_wrong_answers_v1';
  static const _syncQueueKey = 'lp_engine_pending_sync_v1';
  static const _attemptLimitKey = 'lp_engine_attempt_limit_v1';
  static const _attemptsUsedKey = 'lp_engine_attempts_used_v1';
  static const _attemptDayKey = 'lp_engine_attempt_day_v1';
  static const _consumedAttemptEventsKey = 'lp_engine_consumed_attempt_events_v1';
  static const _completionDatesKey = 'lp_engine_completion_dates_v1';

  static String normalizeAnswer(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[’‘`´]"), "'")
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Supports one or many accepted answers and tolerates harmless case,
  /// whitespace, and punctuation differences.
  static bool matchesAnswer(String answer, Iterable<String> acceptedAnswers) {
    final normalized = normalizeAnswer(answer);
    return normalized.isNotEmpty &&
        acceptedAnswers.any((accepted) => normalizeAnswer(accepted) == normalized);
  }

  /// Spaced repetition intervals: 1, 3, 7, 14, then doubling up to 90 days.
  /// An incorrect answer schedules a short retry after four hours.
  static int nextReviewInterval({required bool correct, required int previousRepetitions, required int previousIntervalDays}) {
    if (!correct) return 0;
    if (previousRepetitions <= 0) return 1;
    if (previousRepetitions == 1) return 3;
    if (previousRepetitions == 2) return 7;
    if (previousRepetitions == 3) return 14;
    return (previousIntervalDays * 2).clamp(1, 90).toInt();
  }

  static bool isUnlocked({
    required int index,
    required Set<String> completedLessonIds,
    required List<String> orderedLessonIds,
    int requiredScorePercent = 70,
    Map<String, int> bestScores = const {},
  }) {
    if (index <= 0) return true;
    if (index >= orderedLessonIds.length) return false;
    final previous = orderedLessonIds[index - 1];
    return completedLessonIds.contains(previous) &&
        (bestScores[previous] == null || bestScores[previous]! >= requiredScorePercent);
  }

  Future<int> totalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_xpKey) ?? 0;
  }

  Future<int> dailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey) ?? 20;
  }

  Future<void> setDailyGoal(int xp) async {
    if (xp < 5 || xp > 200 || xp % 5 != 0) {
      throw ArgumentError('Daily goal must be 5–200 XP in steps of 5.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, xp);
  }

  Future<int> todayXp({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final daily = _readJsonMap(prefs.getString(_dailyXpKey));
    return (daily[_dateKey(now ?? DateTime.now())] as num?)?.toInt() ?? 0;
  }

  Future<int> streak() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastActiveKey);
    if (last == null) return 0;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return 0;
    final today = _dateOnly(DateTime.now());
    final gap = today.difference(_dateOnly(lastDate)).inDays;
    if (gap > 1) return 0;
    return prefs.getInt(_streakKey) ?? 0;
  }

  /// Idempotent event key prevents duplicate XP when a completion is retried.
  /// Each event is also recorded in a local outbox for a future sync adapter.
  Future<bool> awardXp({
    required String eventId,
    required int points,
    DateTime? now,
  }) async {
    if (eventId.trim().isEmpty || points < 0) {
      throw ArgumentError('A non-empty eventId and non-negative points are required.');
    }
    final prefs = await SharedPreferences.getInstance();
    final awarded = prefs.getStringList(_awardedEventsKey) ?? <String>[];
    if (awarded.contains(eventId)) return false;

    final current = now ?? DateTime.now();
    final today = _dateOnly(current);
    final lastRaw = prefs.getString(_lastActiveKey);
    final last = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    var streak = prefs.getInt(_streakKey) ?? 0;
    if (last == null) {
      streak = 1;
    } else {
      final gap = today.difference(_dateOnly(last)).inDays;
      if (gap == 1) {
        streak += 1;
      } else if (gap > 1) {
        streak = 1;
      }
    }

    final daily = _readJsonMap(prefs.getString(_dailyXpKey));
    final dayKey = _dateKey(current);
    daily[dayKey] = ((daily[dayKey] as num?)?.toInt() ?? 0) + points;
    awarded.add(eventId);
    await prefs.setStringList(_awardedEventsKey, awarded);
    await prefs.setInt(_xpKey, (prefs.getInt(_xpKey) ?? 0) + points);
    await prefs.setString(_dailyXpKey, jsonEncode(daily));
    await prefs.setString(_lastActiveKey, today.toIso8601String());
    await prefs.setInt(_streakKey, streak);

    final outbox = prefs.getStringList(_syncQueueKey) ?? <String>[];
    outbox.add(jsonEncode({
      'eventId': eventId,
      'points': points,
      'createdAt': current.toIso8601String(),
      'type': 'xp_awarded',
    }));
    await prefs.setStringList(_syncQueueKey, outbox);
    return true;
  }

  Future<bool> completeLesson({
    required String lessonId,
    required String completionEventId,
    int xp = 10,
    DateTime? now,
  }) async {
    if (lessonId.trim().isEmpty || completionEventId.trim().isEmpty) throw ArgumentError('lessonId and completionEventId are required.');
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_completedKey) ?? <String>[];
    final isNewCompletion = !completed.contains(lessonId);
    if (isNewCompletion) {
      completed.add(lessonId);
      await prefs.setStringList(_completedKey, completed);
    }
    final current = now ?? DateTime.now();
    if (isNewCompletion) {
      final dates = _readJsonMap(prefs.getString(_completionDatesKey));
      dates[lessonId] = _dateKey(current);
      await prefs.setString(_completionDatesKey, jsonEncode(dates));
      final outbox = prefs.getStringList(_syncQueueKey) ?? <String>[];
      outbox.add(jsonEncode({
        'eventId': 'lesson-completed:$lessonId',
        'type': 'lesson_completed',
        'lessonId': lessonId,
        'createdAt': current.toIso8601String(),
      }));
      await prefs.setStringList(_syncQueueKey, outbox);
    }
    final awarded = await awardXp(eventId: 'lesson:$lessonId', points: xp, now: current);
    return isNewCompletion || awarded;
  }

  /// One-time compatibility bridge from the former LearningStore ledger.
  /// The engine becomes the canonical completion/XP source after this import.
  Future<void> migrateLegacyProgress({
    required Iterable<String> completedLessonIds,
    required int legacyXp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_completedKey) ?? <String>[];
    final awarded = prefs.getStringList(_awardedEventsKey) ?? <String>[];
    var completedChanged = false;
    var awardedChanged = false;
    for (final rawId in completedLessonIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      if (!completed.contains(id)) {
        completed.add(id);
        completedChanged = true;
      }
      // Legacy completed lessons already received their XP in the old ledger.
      // Mark their stable XP event so reopening one cannot award it a second time.
      final legacyLessonEvent = 'lesson:$id';
      if (!awarded.contains(legacyLessonEvent)) {
        awarded.add(legacyLessonEvent);
        awardedChanged = true;
      }
    }
    if (completedChanged) await prefs.setStringList(_completedKey, completed);
    if (awardedChanged) await prefs.setStringList(_awardedEventsKey, awarded);
    final currentXp = prefs.getInt(_xpKey) ?? 0;
    if (legacyXp > currentXp) await prefs.setInt(_xpKey, legacyXp);
  }

  Future<Set<String>> completedLessons() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedKey) ?? const <String>[]).toSet();
  }

  Future<void> recordAnswer({
    required String eventId,
    required String lessonId,
    required String prompt,
    required String answer,
    required bool correct,
    String? targetTerm,
    String? targetMeaning,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_attemptsKey) ?? <String>[];
    if (events.contains(eventId)) return;
    events.add(eventId);
    await prefs.setStringList(_attemptsKey, events);
    final outbox = prefs.getStringList(_syncQueueKey) ?? <String>[];
    outbox.add(jsonEncode({
      'eventId': 'answer:$eventId',
      'type': 'answer_recorded',
      'lessonId': lessonId,
      'prompt': prompt,
      'answer': answer,
      'correct': correct,
      'targetTerm': targetTerm,
      'targetMeaning': targetMeaning,
      'createdAt': (now ?? DateTime.now()).toIso8601String(),
    }));
    await prefs.setStringList(_syncQueueKey, outbox);

    if (!correct) {
      final mistakes = prefs.getStringList(_wrongAnswersKey) ?? <String>[];
      mistakes.add(jsonEncode({
        'eventId': eventId,
        'lessonId': lessonId,
        'prompt': prompt,
        'answer': answer,
        'targetTerm': targetTerm,
        'targetMeaning': targetMeaning,
        'createdAt': (now ?? DateTime.now()).toIso8601String(),
        'resolved': false,
      }));
      await prefs.setStringList(_wrongAnswersKey, mistakes);
    }
  }

  Future<List<Map<String, dynamic>>> mistakes({bool unresolvedOnly = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_wrongAnswersKey) ?? <String>[];
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      try {
        final item = Map<String, dynamic>.from(jsonDecode(entry) as Map);
        if (!unresolvedOnly || item['resolved'] != true) items.add(item);
      } catch (_) {}
    }
    return items;
  }

  Future<void> markMistakeResolved(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_wrongAnswersKey) ?? <String>[];
    final updated = <String>[];
    for (final entry in raw) {
      try {
        final item = Map<String, dynamic>.from(jsonDecode(entry) as Map);
        if (item['eventId'] == eventId) item['resolved'] = true;
        updated.add(jsonEncode(item));
      } catch (_) {
        updated.add(entry);
      }
    }
    await prefs.setStringList(_wrongAnswersKey, updated);
  }

  Future<List<Map<String, dynamic>>> pendingSyncEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_syncQueueKey) ?? <String>[];
    return raw.map((entry) {
      try {
        return Map<String, dynamic>.from(jsonDecode(entry) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((item) => item.isNotEmpty).toList(growable: false);
  }


  /// Configure daily attempts. Zero means unlimited; the default is unlimited.
  Future<void> setDailyAttemptLimit(int limit) async {
    if (limit < 0 || limit > 20) {
      throw ArgumentError('Daily attempt limit must be between 0 and 20.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_attemptLimitKey, limit);
    await prefs.setInt(_attemptsUsedKey, 0);
    await prefs.setString(_attemptDayKey, _dateKey(DateTime.now()));
  }

  Future<int> dailyAttemptLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptLimitKey) ?? 0;
  }

  Future<int?> attemptsRemaining({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final limit = prefs.getInt(_attemptLimitKey) ?? 0;
    if (limit == 0) return null;
    final date = _dateKey(now ?? DateTime.now());
    final savedDate = prefs.getString(_attemptDayKey);
    final used = savedDate == date ? (prefs.getInt(_attemptsUsedKey) ?? 0) : 0;
    return (limit - used).clamp(0, limit);
  }

  /// Consumes an attempt once per event. Returns false when no attempts remain.
  Future<bool> consumeAttempt(String eventId, {DateTime? now}) async {
    if (eventId.trim().isEmpty) throw ArgumentError('eventId is required.');
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_consumedAttemptEventsKey) ?? <String>[];
    if (events.contains(eventId)) return true;
    final current = now ?? DateTime.now();
    final date = _dateKey(current);
    final limit = prefs.getInt(_attemptLimitKey) ?? 0;
    final used = prefs.getString(_attemptDayKey) == date ? (prefs.getInt(_attemptsUsedKey) ?? 0) : 0;
    if (limit > 0 && used >= limit) return false;
    events.add(eventId);
    await prefs.setStringList(_consumedAttemptEventsKey, events);
    await prefs.setString(_attemptDayKey, date);
    await prefs.setInt(_attemptsUsedKey, used + 1);
    return true;
  }

  /// Simple, transparent challenges based on locally stored lesson completions.
  Future<Map<String, int>> challengeSummary({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final dates = _readJsonMap(prefs.getString(_completionDatesKey));
    final current = _dateOnly(now ?? DateTime.now());
    var today = 0;
    var thisWeek = 0;
    for (final value in dates.values) {
      if (value is! String) continue;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) continue;
      final day = _dateOnly(parsed);
      final age = current.difference(day).inDays;
      if (age == 0) today++;
      if (age >= 0 && age < 7) thisWeek++;
    }
    return <String, int>{
      'dailyLessons': today,
      'dailyTarget': 1,
      'weeklyLessons': thisWeek,
      'weeklyTarget': 5,
    };
  }

  Future<List<String>> unlockedBadges() async {
    final completed = await completedLessons();
    final xp = await totalXp();
    final currentStreak = await streak();
    final badges = <String>[];
    if (completed.isNotEmpty) badges.add('البداية');
    if (completed.length >= 3) badges.add('المثابرة');
    if (completed.length >= 10) badges.add('عشرة دروس');
    if (xp >= 100) badges.add('جامع الخبرة');
    if (currentStreak >= 3) badges.add('ثلاثة أيام متتالية');
    if (currentStreak >= 7) badges.add('أسبوع من التعلّم');
    return badges;
  }

  static Map<String, dynamic> _readJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
