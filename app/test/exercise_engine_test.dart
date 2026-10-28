import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/services/exercise_engine.dart';

void main() {
  const engine = ExerciseEngine();

  test('accepts multiple valid answers for free-text exercises', () {
    final question = ExerciseQuestion.fromJson({
      'id': 'greeting-1',
      'type': 'translation',
      'prompt': 'Translate: اسمي سارة',
      'accepted_answers': ['My name is Sara', "I'm Sara"],
      'explanation': 'Both forms introduce a name naturally.',
    });
    expect(engine.grade(question, "  I'M Sara! ").isCorrect, isTrue);
    expect(engine.grade(question, 'My name is Sara').isCorrect, isTrue);
    expect(engine.grade(question, 'Sara name my').isCorrect, isFalse);
  });

  test('grades multiple choice and listening choice locally', () {
    final question = ExerciseQuestion.fromJson({
      'id': 'listen-1', 'type': 'listening_choice', 'prompt': 'Choose the word you heard',
      'options': ['court', 'house', 'book'], 'answer_index': 0,
    });
    expect(engine.grade(question, 0).isCorrect, isTrue);
    expect(engine.grade(question, 2).isCorrect, isFalse);
  });

  test('matching requires every defined pair to be correct', () {
    final question = ExerciseQuestion.fromJson({
      'id': 'match-1', 'type': 'matching', 'prompt': 'Match terms',
      'pairs': [{'left': 'judge', 'right': 'قاضٍ'}, {'left': 'witness', 'right': 'شاهد'}],
    });
    expect(engine.grade(question, {'judge': 'قاضٍ', 'witness': 'شاهد'}).isCorrect, isTrue);
    expect(engine.grade(question, {'judge': 'محامٍ', 'witness': 'شاهد'}).isCorrect, isFalse);
  });

  test('writing and court scenarios are not marked correct without a rubric', () {
    final writing = ExerciseQuestion.fromJson({
      'id': 'writing-1', 'type': 'court_scenario', 'prompt': 'Ask a witness what they saw.',
    });
    final result = engine.grade(writing, 'What did you see?');
    expect(result.isAutoGraded, isFalse);
    expect(result.isCorrect, isNull);
  });

  test('unknown exercise types are rejected instead of silently misgraded', () {
    expect(
      () => ExerciseQuestion.fromJson({'id': 'bad', 'type': 'telepathy', 'prompt': 'x'}),
      throwsFormatException,
    );
  });
}
