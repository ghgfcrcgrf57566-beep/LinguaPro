import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';
import 'package:english_learning_legal_academy/features/learning/micro_lesson_flow.dart';

LearningLesson sampleLesson({int vocabularyCount = 2}) {
  final words = <LearningWord>[
    const LearningWord(
      term: 'Client',
      meaning: 'عميل / موكل',
      example: 'The client is at reception.',
      pronunciation: 'KLY-ent',
    ),
    const LearningWord(
      term: 'Lawyer',
      meaning: 'محامٍ',
      example: 'The lawyer meets the client.',
    ),
    const LearningWord(
      term: 'Office',
      meaning: 'مكتب',
      example: 'The lawyer is in the office.',
    ),
  ];
  return LearningLesson(
    id: 'legal-eng-greeting-client',
    title: 'Greeting a client',
    level: 'A1',
    track: 'legal-english',
    description: 'Greet a client at a law office.',
    objectives: const <String>['Greet a client', 'Use legal office vocabulary'],
    vocabulary: words.take(vocabularyCount).toList(growable: false),
    sections: const <LearningSection>[
      LearningSection(heading: 'Dialogue', body: 'The client is at reception. The lawyer is in the office.'),
    ],
    quiz: const <LessonQuestion>[
      LessonQuestion(
        question: 'Who is waiting at reception?',
        options: <String>['The client', 'The court', 'The judge'],
        answerIndex: 0,
        explanation: 'The client is waiting at reception.',
      ),
    ],
  );
}

void main() {
  group('MicroLessonFlow', () {
    test('creates eight short steps with the expected Duolingo-inspired sequence', () {
      final steps = MicroLessonFlow.build(sampleLesson());

      expect(steps, hasLength(8));
      expect(steps.map((step) => step.type).toList(), <MicroStepType>[
        MicroStepType.presentation,
        MicroStepType.imageChoice,
        MicroStepType.audioChoice,
        MicroStepType.wordBank,
        MicroStepType.presentation,
        MicroStepType.fillBlank,
        MicroStepType.speakingPractice,
        MicroStepType.hardChallenge,
      ]);
      expect(steps[0].word?.term, 'Client');
      expect(steps[1].options[steps[1].answerIndex!], 'عميل / موكل');
      expect(steps[2].options[steps[2].answerIndex!], 'Client');
      expect(steps[3].acceptedAnswers, <String>['The client is at reception.']);
      expect(steps[4].word?.term, 'Lawyer');
      expect(steps[7].answerIndex, 0);
    });

    test('keeps four visual and audio options when a lesson has only one word', () {
      final steps = MicroLessonFlow.build(sampleLesson(vocabularyCount: 1));

      expect(steps[1].options, hasLength(4));
      expect(steps[2].options, hasLength(4));
      expect(steps[5].options, hasLength(4));
    });

    test('word bank options contain every target token and are not the untouched sentence order', () {
      final steps = MicroLessonFlow.build(sampleLesson());
      final wordBank = steps.firstWhere((step) => step.type == MicroStepType.wordBank);
      final expected = wordBank.acceptedAnswers.single.split(RegExp(r'\\s+'));
      final actual = wordBank.options.toSet();

      for (final token in expected) {
        expect(actual, contains(token));
      }
      expect(wordBank.options.join(' '), isNot(wordBank.acceptedAnswers.single));
    });
  });
}
