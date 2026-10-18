import 'package:flutter_test/flutter_test.dart';
import 'package:boykotbarkodu/main.dart';

void main() {
  testWidgets('App initializes test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoykotBarkodApp());
    expect(find.byType(BoykotBarkodApp), findsOneWidget);
  });
}
