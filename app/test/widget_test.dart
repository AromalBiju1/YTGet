import 'package:flutter_test/flutter_test.dart';
import 'package:ytget/main.dart';

void main() {
  testWidgets('YTGet shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const YTGetApp());
    expect(find.text('YTGet'), findsOneWidget);
  });
}
