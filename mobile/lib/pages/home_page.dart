import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_chat_page.dart';
import 'operation_plan_page.dart';
import 'settings_page.dart';
import 'stock_list_page.dart';
import 'trading_record_page.dart';

/// 主页 — 底部 Tab 导航
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const StockListPage(),
    const AiChatPage(),
    const TradingRecordPage(),
    const OperationPlanPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        indicatorColor: colorScheme.primaryContainer,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.show_chart, color: colorScheme.primary),
            label: '行情',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.smart_toy, color: colorScheme.primary),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.receipt_long, color: colorScheme.primary),
            label: '交易',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.assignment, color: colorScheme.primary),
            label: '计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.settings, color: colorScheme.primary),
            label: '设置',
          ),
        ],
      ),
    );
  }
}