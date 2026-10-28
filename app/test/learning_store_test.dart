import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';
import 'package:english_learning_legal_academy/services/learning_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferences.setMockInitialValues(<String, Object>{}); });
  group('QuizResult', () {
    test('round-trips a saved score and calculates percentage', () {
      final original = QuizResult(
        lessonId: 'a1-greetings',
        score: 4,
        total: 5,
        completedAt: DateTime.parse('2026-10-28T10:00:00.000'),
      );

      final restored = QuizResult.fromJson(original.toJson());

      expect(restored.lessonId, 'a1-greetings');
      expect(restored.score, 4);
      expect(restored.total, 5);
      expect(restored.percentage, 0.8);
      expect(restored.completedAt, original.completedAt);
    });

    test('zero-question quiz has a safe percentage', () {
      final result = QuizResult(
        lessonId: 'empty-quiz',
        score: 0,
        total: 0,
        completedAt: DateTime(2026, 10, 28),
      );

      expect(result.percentage, 0);
    });
  });

  group('WordProgress practice signals', () {
    test('calculates accuracy and flags repeated mistakes for extra practice', () {
      final word = WordProgress(
        lessonId: 'a1-likes',
        term: 'book',
        meaning: 'كتاب',
        dueAt: DateTime(2026, 10, 28),
        intervalDays: 0,
        repetitions: 0,
        correctCount: 1,
        wrongCount: 2,
        lastResult: false,
      );

      expect(word.attempts, 3);
      expect(word.accuracy, closeTo(1 / 3, 0.001));
      expect(word.needsExtraPractice, isTrue);
    });

    test('does not flag a word without mistakes', () {
      final word = WordProgress(
        lessonId: 'a1-likes',
        term: 'read',
        meaning: 'يقرأ',
        dueAt: DateTime(2026, 10, 29),
        intervalDays: 1,
        repetitions: 1,
        correctCount: 1,
        wrongCount: 0,
        lastResult: true,
      );

      expect(word.accuracy, 1);
      expect(word.needsExtraPractice, isFalse);
    });
    test('recovered vocabulary is no longer marked weak after accuracy improves', () {
      final word = WordProgress(
        lessonId: 'a1-likes',
        term: 'book',
        meaning: 'كتاب',
        dueAt: DateTime(2026, 10, 29),
        intervalDays: 1,
        repetitions: 4,
        correctCount: 8,
        wrongCount: 2,
        lastResult: true,
      );
      expect(word.accuracy, 0.8);
      expect(word.needsExtraPractice, isFalse);
    });
  });

  group('Learning content models', () {
    test('parses vocabulary and lesson metadata', () {
      final lesson = LearningLesson.fromJson({
        'id': 'legal-contract-basics',
        'title': 'أساسيات العقود',
        'level': 'LEGAL',
        'track': 'legal-english',
        'description': 'درس تجريبي',
        'objectives': ['فهم المصطلحات'],
        'vocabulary': [
          {'term': 'Contract', 'meaning': 'عقد', 'example': 'Sign a contract.'}
        ],
        'sections': [
          {'heading': 'تنبيه', 'body': 'تعليم لغوي فقط'}
        ],
        'quiz': [
          {'question': 'ما معنى Contract؟', 'options': ['عقد', 'محكمة'], 'answer_index': 0, 'explanation': 'Contract تعني عقد.'}
        ]
      });
      expect(lesson.isLegal, isTrue);
      expect(lesson.vocabulary.single.term, 'Contract');
      expect(lesson.quiz.single.answerIndex, 0);
    });

    test('rejects quiz answer index outside options', () {
      expect(
        () => LessonQuestion.fromJson({
          'question': 'Q',
          'options': ['A', 'B'],
          'answer_index': 4,
          'explanation': 'E',
        }),
        throwsFormatException,
      );
    });
  });
  group('spaced review queue', () {
    test('weak vocabulary enters review queue while future scheduled words stay out', () async {
      final store = LearningStore.instance;
      await store.recordWord(lessonId: 'a1-greetings', term: 'hello', meaning: 'مرحبًا', correct: true);
      expect(await store.loadDueWords(), isEmpty);
      expect(await store.loadReviewQueue(), isEmpty);

      await store.recordWord(lessonId: 'a1-greetings', term: 'hello', meaning: 'مرحبًا', correct: false);
      final queue = await store.loadReviewQueue();
      expect(queue, hasLength(1));
      expect(queue.single.term, 'hello');
      expect(queue.single.needsExtraPractice, isTrue);
    });

    test('review queue prioritizes weak vocabulary and respects limit', () async {
      final store = LearningStore.instance;
      await store.recordWord(lessonId: 'lesson', term: 'court', meaning: 'محكمة', correct: true);
      await store.recordWord(lessonId: 'lesson', term: 'appeal', meaning: 'استئناف', correct: false);
      final queue = await store.loadReviewQueue(limit: 1);
      expect(queue, hasLength(1));
      expect(queue.single.term, 'appeal');
    });
  });

  test('offline review events remain queued until acknowledged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LearningStore.instance;
    await store.recordWord(
      lessonId: 'a1-greetings',
      term: 'hello',
      meaning: 'مرحبًا',
      correct: false,
      eventId: 'review-event-1',
    );
    await store.recordWord(
      lessonId: 'a1-greetings',
      term: 'goodbye',
      meaning: 'إلى اللقاء',
      correct: true,
      eventId: 'review-event-2',
    );
    final pending = await store.pendingSyncEvents();
    expect(pending.map((event) => event['eventId']).toSet(),
        containsAll(['review-event-1', 'review-event-2']));

    await store.acknowledgeSyncEvents(['review-event-1']);
    final remaining = await store.pendingSyncEvents();
    expect(remaining.map((event) => event['eventId']).toList(), ['review-event-2']);
  });

  test('general and legal tracks include lessons across all CEFR bands', () async {
    Future<List<Map<String, dynamic>>> read(String path) async {
      final data = jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
      return (data['lessons'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final general = [
      ...await read('assets/lessons/english_a1.json'),
      ...await read('assets/lessons/general_expansion.json'),
    ];
    final legal = [
      ...await read('assets/lessons/legal_english.json'),
      ...await read('assets/lessons/legal_expansion.json'),
    ];
    const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    for (final level in levels) {
      expect(general.any((lesson) => lesson['level'] == level), isTrue,
          reason: 'Missing general English content for $level');
      expect(legal.any((lesson) => lesson['level'] == level), isTrue,
          reason: 'Missing legal English content for $level');
    }
    final ids = <String>{};
    for (final lesson in [...general, ...legal]) {
      expect(ids.add(lesson['id'] as String), isTrue, reason: 'Duplicate lesson ID');
      expect((lesson['objectives'] as List).isNotEmpty, isTrue);
      expect((lesson['vocabulary'] as List).isNotEmpty, isTrue);
      expect((lesson['sections'] as List).isNotEmpty, isTrue);
      expect((lesson['quiz'] as List).isNotEmpty, isTrue);
    }
  });

}
