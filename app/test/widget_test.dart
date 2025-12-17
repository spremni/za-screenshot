import 'package:flutter_test/flutter_test.dart';

import 'package:za_screenshot/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ZaScreenshotApp());
    expect(find.text('Za Screenshot'), findsOneWidget);
  });
}
