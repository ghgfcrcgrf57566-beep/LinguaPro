import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const paths = <String>[
    'assets/lessons/english_a1.json',
    'assets/lessons/general_expansion.json',
    'assets/lessons/legal_english.json',
    'assets/lessons/legal_expansion.json',
  ];

  test('all packaged lessons parse and contain valid quiz answers', () async {
    final ids = <String>{};
    var lessonCount = 0;
    var vocabularyCount = 0;

    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      final document = jsonDecode(raw) as Map<String, dynamic>;
      final rows = document['lessons'] as List<dynamic>;
      expect(rows, isNotEmpty, reason: '$path must contain lessons');

      for (final row in rows) {
        final lesson = LearningLesson.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        expect(lesson.id, isNotEmpty);
        expect(ids.add(lesson.id), isTrue,
            reason: 'Duplicate lesson ID: ${lesson.id}');
        expect(lesson.vocabulary, isNotEmpty,
            reason: '${lesson.id} must contain vocabulary');
        expect(lesson.sections, isNotEmpty,
            reason: '${lesson.id} must contain a learning section');

        for (final question in lesson.quiz) {
          expect(question.options, isNotEmpty);
          expect(question.answerIndex, inInclusiveRange(0, question.options.length - 1),
              reason: 'Invalid answer index in ${lesson.id}');
        }

        lessonCount++;
        vocabularyCount += lesson.vocabulary.length;
      }
    }

    expect(lessonCount, greaterThanOrEqualTo(50));
    expect(vocabularyCount, greaterThanOrEqualTo(250));
  });
}
