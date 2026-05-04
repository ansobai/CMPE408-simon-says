import 'package:flutter_test/flutter_test.dart';

import 'package:simon_says/main.dart';

void main() {
  testWidgets('Home screen renders mode cards', (WidgetTester tester) async {
    await tester.pumpWidget(const NeuralRecallApp());

    expect(find.text('Easy mode'), findsOneWidget);
    expect(find.text('Hard Mode'), findsOneWidget);
    expect(find.text('V1.0.0'), findsOneWidget);
  });
}
