import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/features/home/learning_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('learning map loads local lessons and opens the selected lesson', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LearningMapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('LinguaPro'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('خريطة التعلّم'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('خريطة التعلّم'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Greetings and introductions'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Greetings and introductions'));
    await tester.pumpAndSettle();

    expect(find.text('المفردات'), findsOneWidget);
    expect(find.text('الشرح'), findsOneWidget);
    expect(find.text('الاختبار'), findsOneWidget);
  });
}
