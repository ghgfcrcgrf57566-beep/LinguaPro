import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/services/learning_engine.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('local exercise answer checking', () {
    test('accepts multiple valid answers and normalizes case and punctuation', () {
      expect(LearningEngine.matchesAnswer('  I am Sara! ', ['I am Sara', "I'm Sara"]), isTrue);
      expect(LearningEngine.matchesAnswer("DON'T", ["don't", 'do not']), isTrue);
      expect(LearningEngine.matchesAnswer('I am Sara', ['I am Ali', 'I am Omar']), isFalse);
      expect(LearningEngine.matchesAnswer('   ', ['']), isFalse);
    });
  });

  group('progression rules', () {
    test('opens first lesson, then requires prior completion and passing score', () {
      const ids = ['one', 'two', 'three'];
      expect(LearningEngine.isUnlocked(index: 0, completedLessonIds: {}, orderedLessonIds: ids), isTrue);
      expect(LearningEngine.isUnlocked(index: 1, completedLessonIds: {}, orderedLessonIds: ids), isFalse);
      expect(LearningEngine.isUnlocked(index: 1, completedLessonIds: {'one'}, orderedLessonIds: ids, bestScores: {'one': 69}), isFalse);
      expect(LearningEngine.isUnlocked(index: 1, completedLessonIds: {'one'}, orderedLessonIds: ids, bestScores: {'one': 70}), isTrue);
      expect(LearningEngine.isUnlocked(index: 3, completedLessonIds: {'one', 'two'}, orderedLessonIds: ids), isFalse);
    });

    test('spaced review grows gradually and resets after an error', () {
      expect(LearningEngine.nextReviewInterval(correct: true, previousRepetitions: 0, previousIntervalDays: 0), 1);
      expect(LearningEngine.nextReviewInterval(correct: true, previousRepetitions: 1, previousIntervalDays: 1), 3);
      expect(LearningEngine.nextReviewInterval(correct: true, previousRepetitions: 3, previousIntervalDays: 7), 14);
      expect(LearningEngine.nextReviewInterval(correct: true, previousRepetitions: 6, previousIntervalDays: 60), 90);
      expect(LearningEngine.nextReviewInterval(correct: false, previousRepetitions: 5, previousIntervalDays: 30), 0);
    });

    test('XP event IDs are idempotent and lesson replay cannot farm XP', () async {
      final engine = LearningEngine.instance;
      final first = await engine.awardXp(eventId: 'quiz:attempt-1', points: 5, now: DateTime(2026, 10, 28, 9));
      final duplicate = await engine.awardXp(eventId: 'quiz:attempt-1', points: 5, now: DateTime(2026, 10, 28, 9));
      expect(first, isTrue);
      expect(duplicate, isFalse);
      expect(await engine.totalXp(), 5);

      await engine.completeLesson(lessonId: 'greetings', completionEventId: 'finish-1', now: DateTime(2026, 10, 28, 10));
      await engine.completeLesson(lessonId: 'greetings', completionEventId: 'finish-retry', now: DateTime(2026, 10, 28, 10));
      expect(await engine.totalXp(), 15);
      expect(await engine.completedLessons(), contains('greetings'));
      expect((await engine.pendingSyncEvents()).length, 2);
    });

    test('daily goal is configurable with safe limits', () async {
      final engine = LearningEngine.instance;
      expect(await engine.dailyGoal(), 20);
      await engine.setDailyGoal(35);
      expect(await engine.dailyGoal(), 35);
      await expectLater(engine.setDailyGoal(33), throwsArgumentError);
      await expectLater(engine.setDailyGoal(500), throwsArgumentError);
    });

    test('wrong answer events are stored once and can be reviewed/resolved', () async {
      final engine = LearningEngine.instance;
      final data = {
        'eventId': 'answer-1', 'lessonId': 'a1-greetings', 'prompt': 'Translate hello',
        'answer': 'goodbye', 'correct': false, 'targetTerm': 'hello', 'targetMeaning': 'مرحبًا',
      };
      await engine.recordAnswer(eventId: data['eventId']!, lessonId: data['lessonId']!, prompt: data['prompt']!, answer: data['answer']!, correct: false, targetTerm: data['targetTerm'], targetMeaning: data['targetMeaning']);
      await engine.recordAnswer(eventId: data['eventId']!, lessonId: data['lessonId']!, prompt: data['prompt']!, answer: data['answer']!, correct: false, targetTerm: data['targetTerm'], targetMeaning: data['targetMeaning']);
      expect((await engine.mistakes()).length, 1);
      await engine.markMistakeResolved('answer-1');
      expect(await engine.mistakes(), isEmpty);
      expect((await engine.mistakes(unresolvedOnly: false)).single['resolved'], isTrue);
    });
  });
}
