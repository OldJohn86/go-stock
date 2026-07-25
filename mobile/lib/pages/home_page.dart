import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stock_list_page.dart';

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
    const _AiChatPlaceholder(),
    const _SettingsPlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            selectedIcon: Icon(Icons.show_chart, color: Colors.blue),
            label: '行情',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy, color: Colors.blue),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.blue),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _AiChatPlaceholder extends StatelessWidget {
  const _AiChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('AI 分析', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('即将上线，敬请期待',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('go-stock Mobile',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('v1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const ListTile(
          leading: Icon(Icons.api),
          title: Text('API 地址'),
          subtitle: Text('http://10.0.2.2:8080'),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('关于'),
          subtitle: Text('AI 赋能股票分析'),
        ),
      ],
    );
  }
}
