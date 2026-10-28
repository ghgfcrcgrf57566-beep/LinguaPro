import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:english_learning_legal_academy/app/academy_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('dashboard shows the game-like learning path', (tester) async {
    await tester.pumpWidget(const AcademyApp());
    await tester.pumpAndSettle();

    expect(find.text('LinguaPro'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('خريطة التعلّم'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('خريطة التعلّم'), findsOneWidget);
    expect(find.text('تحدياتك'), findsOneWidget);
  });
}
