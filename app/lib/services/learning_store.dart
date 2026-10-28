import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WordProgress {
  const WordProgress({
    required this.lessonId,
    required this.term,
    required this.meaning,
    required this.dueAt,
    required this.intervalDays,
    required this.repetitions,
    required this.correctCount,
    required this.wrongCount,
    required this.lastResult,
  });

  final String lessonId;
  final String term;
  final String meaning;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final int correctCount;
  final int wrongCount;
  final bool? lastResult;

  bool get isDue => !dueAt.isAfter(DateTime.now());

  factory WordProgress.fromJson(Map<String, dynamic> json) => WordProgress(
        lessonId: json['lessonId'] as String? ?? '',
        term: json['term'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
        intervalDays: json['intervalDays'] as int? ?? 0,
        repetitions: json['repetitions'] as int? ?? 0,
        correctCount: json['correctCount'] as int? ?? 0,
        wrongCount: json['wrongCount'] as int? ?? 0,
        lastResult: json['lastResult'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'term': term,
        'meaning': meaning,
        'dueAt': dueAt.toIso8601String(),
        'intervalDays': intervalDays,
        'repetitions': repetitions,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'lastResult': lastResult,
      };
}

class QuizResult {
  const QuizResult({
    required this.lessonId,
    required this.score,
    required this.total,
    required this.completedAt,
  });

  final String lessonId;
  final int score;
  final int total;
  final DateTime completedAt;

  double get percentage => total <= 0 ? 0 : score / total;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        lessonId: json['lessonId'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'score': score,
        'total': total,
        'completedAt': completedAt.toIso8601String(),
      };
}

class LearningStore {
  LearningStore._();
  static final LearningStore instance = LearningStore._();
  static const _progressKey = 'linguapro_word_progress_v1';
  static const _lessonKey = 'linguapro_completed_lessons_v1';
  static const _quizResultsKey = 'linguapro_quiz_results_v1';

  Future<Map<String, WordProgress>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(
            key,
            WordProgress.fromJson(Map<String, dynamic>.from(value as Map)),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<void> recordWord({
    required String lessonId,
    required String term,
    required String meaning,
    required bool correct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final progress = await loadProgress();
    final key = _key(lessonId, term);
    final old = progress[key];
    final repetitions = correct ? (old?.repetitions ?? 0) + 1 : 0;
    final interval = correct
        ? (old == null || old.repetitions == 0
            ? 1
            : old.repetitions == 1
                ? 3
                : old.repetitions == 2
                    ? 7
                    : (old.intervalDays * 2).clamp(1, 90).toInt())
        : 0;
    final due = DateTime.now().add(Duration(days: correct ? interval : 0, hours: correct ? 0 : 4));
    progress[key] = WordProgress(
      lessonId: lessonId,
      term: term,
      meaning: meaning,
      dueAt: due,
      intervalDays: interval,
      repetitions: repetitions,
      correctCount: (old?.correctCount ?? 0) + (correct ? 1 : 0),
      wrongCount: (old?.wrongCount ?? 0) + (correct ? 0 : 1),
      lastResult: correct,
    );
    await prefs.setString(_progressKey, jsonEncode(
      progress.map((k, value) => MapEntry(k, value.toJson())),
    ));
  }

  Future<List<QuizResult>> loadQuizResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_quizResultsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => QuizResult.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> recordQuizResult({
    required String lessonId,
    required int score,
    required int total,
  }) async {
    if (lessonId.trim().isEmpty || total < 0 || score < 0 || score > total) {
      throw ArgumentError('Invalid quiz result.');
    }
    final prefs = await SharedPreferences.getInstance();
    final results = await loadQuizResults();
    results.add(QuizResult(
      lessonId: lessonId,
      score: score,
      total: total,
      completedAt: DateTime.now(),
    ));
    await prefs.setString(
      _quizResultsKey,
      jsonEncode(results.map((result) => result.toJson()).toList()),
    );
  }

  Future<Map<String, QuizResult>> bestQuizResults() async {
    final results = await loadQuizResults();
    final best = <String, QuizResult>{};
    for (final result in results) {
      final previous = best[result.lessonId];
      if (previous == null ||
          result.percentage > previous.percentage ||
          (result.percentage == previous.percentage &&
              result.completedAt.isAfter(previous.completedAt))) {
        best[result.lessonId] = result;
      }
    }
    return best;
  }

  Future<Set<String>> completedLessons() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_lessonKey) ?? const <String>[]).toSet();
  }

  Future<void> markLessonComplete(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = await completedLessons();
    completed.add(lessonId);
    await prefs.setStringList(_lessonKey, completed.toList());
  }

  static String keyFor(String lessonId, String term) =>
      _key(lessonId, term);

  static String _key(String lessonId, String term) =>
      '${lessonId.toLowerCase()}::${term.trim().toLowerCase()}';
}
