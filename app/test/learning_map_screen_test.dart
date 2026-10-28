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

    expect(find.text('خريطة التعلّم'), findsOneWidget);
    expect(find.text('الإنجليزية العامة'), findsOneWidget);
    expect(find.text('الإنجليزية القانونية'), findsOneWidget);
    expect(find.text('Greetings and introductions'), findsOneWidget);

    await tester.tap(find.text('Greetings and introductions'));
    await tester.pumpAndSettle();

    expect(find.text('المفردات'), findsOneWidget);
    expect(find.text('الشرح'), findsOneWidget);
    expect(find.text('الاختبار'), findsOneWidget);
  });
}
