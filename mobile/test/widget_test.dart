import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_stock_mobile/main.dart';

void main() {
  testWidgets('App should display bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GoStockApp()));

    // 验证底部导航存在
    expect(find.text('行情'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
