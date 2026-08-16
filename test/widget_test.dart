import 'package:flutter_test/flutter_test.dart';
import 'package:sitechain/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const SiteChainApp());
    expect(find.text('SiteChain'), findsWidgets);
  });
}
