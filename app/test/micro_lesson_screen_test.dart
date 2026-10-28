import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/features/learning/micro_lesson_screen.dart';
import 'package:english_learning_legal_academy/services/learning_sound_service.dart';
import 'package:english_learning_legal_academy/models/learning_lesson.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('micro lesson starts with word presentation and checks a visual choice', (tester) async {
    const lesson = LearningLesson(
      id: 'legal-eng-greeting-client',
      title: 'Greeting a client',
      level: 'A1',
      track: 'legal-english',
      description: 'Greet a client at a law office.',
      objectives: <String>['Greet a client'],
      vocabulary: <LearningWord>[
        LearningWord(
          term: 'Client',
          meaning: 'عميل / موكل',
          example: 'The client is at reception.',
          pronunciation: 'KLY-ent',
        ),
        LearningWord(
          term: 'Lawyer',
          meaning: 'محامٍ',
          example: 'The lawyer meets the client.',
        ),
      ],
      sections: <LearningSection>[
        LearningSection(heading: 'Dialogue', body: 'The client is at reception.'),
      ],
      quiz: <LessonQuestion>[
        LessonQuestion(
          question: 'Who is waiting at reception?',
          options: <String>['The client', 'The court', 'The judge'],
          answerIndex: 0,
          explanation: 'The client is waiting at reception.',
        ),
      ],
    );

    await LearningSoundService.instance.setEnabled(false);
    await tester.pumpWidget(const MaterialApp(home: MicroLessonScreen(lesson: lesson)));
    await tester.pumpAndSettle();

    expect(find.text('Client'), findsOneWidget);
    expect(find.text('عميل / موكل'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اختر المعنى الصحيح'), findsOneWidget);

    await tester.tap(find.text('عميل / موكل'));
    await tester.tap(find.text('تحقّق'));
    await tester.pumpAndSettle();
    expect(
      find.text('ممتاز!').evaluate().isNotEmpty ||
          find.text('رائع!').evaluate().isNotEmpty ||
          find.text('إجابة مذهلة!').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('الإجابة الصحيحة: عميل / موكل'), findsNothing);
    expect(find.text('المتابعة'), findsOneWidget);
  });
}
