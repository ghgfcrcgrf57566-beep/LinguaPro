import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/features/learning/spaced_review_screen.dart';
import 'package:english_learning_legal_academy/services/learning_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferences.setMockInitialValues(<String, Object>{}); });

  testWidgets('spaced review loads weak words, checks an answer and completes the session', (tester) async {
    await LearningStore.instance.recordWord(
      lessonId: 'a1-greetings',
      term: 'hello',
      meaning: 'مرحبًا',
      correct: false,
      eventId: 'seed-weak-word',
    );

    await tester.pumpWidget(const MaterialApp(home: SpacedReviewScreen()));
    await tester.pumpAndSettle();
    expect(find.text('مرحبًا'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('تحقق من الإجابة'));
    await tester.pumpAndSettle();
    expect(find.text('إجابة صحيحة، أحسنت!'), findsOneWidget);

    await tester.tap(find.text('إنهاء المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('اكتملت جلسة المراجعة!'), findsOneWidget);
  });
}
