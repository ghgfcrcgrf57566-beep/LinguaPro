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
      expect(LearningEngine.isUnlocked(index: 1, completedLessonIds: {'one'}, orderedLessonIds: ids), isFalse,
          reason: 'Completion without a recorded passing quiz must not unlock the next lesson.');
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
      expect((await engine.pendingSyncEvents()).length, 3);
      final challenge = await engine.challengeSummary(now: DateTime(2026, 10, 28, 10));
      expect(challenge['dailyLessons'], 1);
      expect(challenge['weeklyLessons'], 1);
      expect(await engine.unlockedBadges(), contains('البداية'));
    });

    test('legacy completion and XP migrate without awarding duplicate XP', () async {
      final engine = LearningEngine.instance;
      await engine.migrateLegacyProgress(
        completedLessonIds: ['legacy-lesson'],
        legacyXp: 30,
      );
      expect(await engine.completedLessons(), contains('legacy-lesson'));
      expect(await engine.totalXp(), 30);
      await engine.completeLesson(
        lessonId: 'legacy-lesson',
        completionEventId: 'legacy-replay',
      );
      expect(await engine.totalXp(), 30,
          reason: 'A migrated lesson must not award XP again on replay.');

      await engine.migrateLegacyProgress(
        completedLessonIds: ['legacy-lesson', 'another-legacy-lesson'],
        legacyXp: 20,
      );
      expect(await engine.completedLessons(),
          containsAll(['legacy-lesson', 'another-legacy-lesson']));
      expect(await engine.totalXp(), 30);
    });

    test('daily goal is configurable with safe limits', () async {
      final engine = LearningEngine.instance;
      expect(await engine.dailyGoal(), 20);
      await engine.setDailyGoal(35);
      expect(await engine.dailyGoal(), 35);
      await expectLater(engine.setDailyGoal(33), throwsArgumentError);
      await expectLater(engine.setDailyGoal(500), throwsArgumentError);
    });

    test('attempt limits are configurable, daily, and idempotent by event', () async {
      final engine = LearningEngine.instance;
      expect(await engine.attemptsRemaining(now: DateTime(2026, 10, 28)), isNull);
      await engine.setDailyAttemptLimit(2);
      expect(await engine.attemptsRemaining(now: DateTime(2026, 10, 28)), 2);
      expect(await engine.consumeAttempt('try-1', now: DateTime(2026, 10, 28)), isTrue);
      expect(await engine.consumeAttempt('try-1', now: DateTime(2026, 10, 28)), isTrue);
      expect(await engine.attemptsRemaining(now: DateTime(2026, 10, 28)), 1);
      expect(await engine.consumeAttempt('try-2', now: DateTime(2026, 10, 28)), isTrue);
      expect(await engine.consumeAttempt('try-3', now: DateTime(2026, 10, 28)), isFalse);
      expect(await engine.attemptsRemaining(now: DateTime(2026, 10, 29)), 2);
    });

    test('wrong answer events are stored once and can be reviewed/resolved', () async {
      final engine = LearningEngine.instance;
      final data = <String, dynamic>{
        'eventId': 'answer-1', 'lessonId': 'a1-greetings', 'prompt': 'Translate hello',
        'answer': 'goodbye', 'correct': false, 'targetTerm': 'hello', 'targetMeaning': 'مرحبًا',
      };
      await engine.recordAnswer(eventId: data['eventId'] as String, lessonId: data['lessonId'] as String, prompt: data['prompt'] as String, answer: data['answer'] as String, correct: false, targetTerm: data['targetTerm'] as String, targetMeaning: data['targetMeaning'] as String);
      await engine.recordAnswer(eventId: data['eventId']!, lessonId: data['lessonId']!, prompt: data['prompt']!, answer: data['answer']!, correct: false, targetTerm: data['targetTerm'], targetMeaning: data['targetMeaning']);
      expect((await engine.mistakes()).length, 1);
      await engine.markMistakeResolved('answer-1');
      expect(await engine.mistakes(), isEmpty);
      expect((await engine.mistakes(unresolvedOnly: false)).single['resolved'], isTrue);
    });
  });
}
