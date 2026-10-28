import 'package:flutter_test/flutter_test.dart';
import 'package:english_learning_legal_academy/app/academy_app.dart';

void main() {
  testWidgets('dashboard shows key learning tracks', (tester) async {
    await tester.pumpWidget(const AcademyApp());
    expect(find.text('أكاديمية الإنجليزية'), findsOneWidget);
    expect(find.text('مسارات التعلّم'), findsOneWidget);
    expect(find.text('أكاديمية الإنجليزية القانونية'), findsOneWidget);
    expect(find.text('المعلّم الذكي'), findsOneWidget);
  });
}
