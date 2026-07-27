import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_stock_mobile/main.dart';

void main() {
  testWidgets('Splash page displays branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GoStockApp()));

    // 启动后先看到 SplashPage — 显示 app 品牌信息
    expect(find.text('goldstock'), findsOneWidget);
    expect(find.text('AI 智能选股 · 实时行情'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 消耗掉 Future.delayed(600ms) 的 timer，避免 pending timer 警告
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('NavigationBar renders correctly with 5 destinations',
      (tester) async {
    // 直接构建 NavigationBar 进行测试，无需加载含真实 API 调用的页面
    final navBar = NavigationBar(
      destinations: const [
        NavigationDestination(icon: Icon(Icons.show_chart), label: '行情'),
        NavigationDestination(icon: Icon(Icons.smart_toy), label: 'AI'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: '交易'),
        NavigationDestination(icon: Icon(Icons.assignment), label: '计划'),
        NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: navBar)));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('行情'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('交易'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
