import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';
import 'package:english_learning_legal_academy/services/learning_store.dart';

void main() {
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
}
