import 'package:flutter_test/flutter_test.dart';

import 'package:simon_says/main.dart';

void main() {
  testWidgets('Home screen renders mode cards', (WidgetTester tester) async {
    await tester.pumpWidget(const NeuralRecallApp());

    expect(find.text('Focus Mode'), findsOneWidget);
    expect(find.text('Overdrive Mode'), findsOneWidget);
    expect(find.text('SYSTEM ACTIVE V2.0.4'), findsOneWidget);
  });
}
