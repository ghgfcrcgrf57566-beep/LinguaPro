import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';

void main() {
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
