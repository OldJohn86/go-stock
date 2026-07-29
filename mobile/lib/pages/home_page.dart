import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/network_error_banner.dart';
import 'ai_chat_page.dart';
import 'market_page.dart';
import 'settings_page.dart';
import 'stock_list_page.dart';
import 'stock_search_page.dart';
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
    const MarketPage(),
    const AiChatPage(),
    const TradingRecordPage(),
    const SettingsPage(),
  ];

  String _titleForTab(int index) {
    switch (index) {
      case 0:
        return '行情';
      case 1:
        return '市场';
      case 2:
        return 'AI 分析';
      case 3:
        return '交易';
      case 4:
        return '设置';
      default:
        return '';
    }
  }

  void _openStockSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StockSearchPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForTab(_currentIndex)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索股票',
            onPressed: _openStockSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          const NetworkErrorBanner(),
          Expanded(
            child: AnimatedSwitcher(
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
          ),
        ],
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
            icon: Icon(Icons.explore_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.explore, color: colorScheme.primary),
            label: '市场',
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
            icon: Icon(Icons.settings_outlined, color: Colors.grey[500]),
            selectedIcon: Icon(Icons.settings, color: colorScheme.primary),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
