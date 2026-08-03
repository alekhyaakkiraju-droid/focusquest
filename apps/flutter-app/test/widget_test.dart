import 'package:flutter_test/flutter_test.dart';
import 'package:focusquest/main.dart';

void main() {
  testWidgets('renders app title', (tester) async {
    await tester.pumpWidget(const FocusQuestApp());
    expect(find.text('FocusQuest'), findsOneWidget);
  });
}
