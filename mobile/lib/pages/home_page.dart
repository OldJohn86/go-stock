import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/network_error_banner.dart';
import 'ai_chat_page.dart';
import 'ai_config_page.dart';
import 'ai_recommend_stocks_page.dart';
import 'ai_report_page.dart';
import 'alert_setting_page.dart';
import 'backtest_page.dart';
import 'dashboard_page.dart';
import 'fund_list_page.dart';
import 'hot_market_page.dart';
import 'long_tiger_page.dart';
import 'market_radar_page.dart';
import 'stock_notice_page.dart';
import 't0_trade_page.dart';
import 'operation_plan_page.dart';
import 'sector_ranking_page.dart';
import 'settings_page.dart';
import 'tdx_deep_data_page.dart';
import 'kline_pattern_page.dart';
import 'risk_control_page.dart';
import 'cron_task_page.dart';
import 'mcp_server_page.dart';
import 'stock_list_page.dart';
import 'stock_screener_page.dart';
import 'stock_search_page.dart';
import 'trading_calendar_page.dart';
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

  String _titleForTab(int index) {
    switch (index) {
      case 0:
        return '行情';
      case 1:
        return 'AI 分析';
      case 2:
        return '交易日志';
      case 3:
        return '每日操作计划';
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
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              tooltip: '技术指标筛选',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockScreenerPage()),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: '更多功能',
              onSelected: (v) {
                switch (v) {
                  case 'sector':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SectorRankingPage()),
                    );
                  case 'ai_recommend':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiRecommendStocksPage()),
                    );
                  case 'alert':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlertSettingPage()),
                    );
                  case 'backtest':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BacktestPage()),
                    );
                  case 't0':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const T0TradePage()),
                    );
                  case 'dashboard':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    );
                  case 'radar':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MarketRadarPage()),
                    );
                  case 'hot_market':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HotMarketPage()),
                    );
                  case 'long_tiger':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LongTigerPage()),
                    );
                  case 'ai_report':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiReportPage()),
                    );
                  case 'ai_config':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiConfigPage()),
                    );
                  case 'fund':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FundListPage()),
                    );
                  case 'stock_notice':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StockNoticePage()),
                    );
                  case 'risk_control':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RiskControlPage()),
                    );
                  case 'cron_task':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CronTaskPage()),
                    );
                  case 'kline_pattern':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KLinePatternPage()),
                    );
                  case 'tdx_deep':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TdxDeepDataPage()),
                    );
                  case 'mcp_server':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const McpServerPage()),
                    );
                  case 'calendar':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TradingCalendarPage()),
                    );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'sector',
                  child: ListTile(
                    leading: Icon(Icons.grid_view),
                    title: Text('板块行情'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'ai_recommend',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome),
                    title: Text('AI推荐股票'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'alert',
                  child: ListTile(
                    leading: Icon(Icons.notifications_active),
                    title: Text('盘中预警'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'backtest',
                  child: ListTile(
                    leading: Icon(Icons.analytics),
                    title: Text('交易回测'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 't0',
                  child: ListTile(
                    leading: Icon(Icons.swap_horiz),
                    title: Text('做T提醒'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'dashboard',
                  child: ListTile(
                    leading: Icon(Icons.dashboard),
                    title: Text('大盘仪表盘'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'radar',
                  child: ListTile(
                    leading: Icon(Icons.radar),
                    title: Text('行情雷达'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'hot_market',
                  child: ListTile(
                    leading: Icon(Icons.local_fire_department),
                    title: Text('热门市场'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'long_tiger',
                  child: ListTile(
                    leading: Icon(Icons.trending_up),
                    title: Text('龙虎榜'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'stock_notice',
                  child: ListTile(
                    leading: Icon(Icons.article_outlined),
                    title: Text('股票公告'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'ai_report',
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('AI研究报告'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'ai_config',
                  child: ListTile(
                    leading: Icon(Icons.tune),
                    title: Text('AI配置管理'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'fund',
                  child: ListTile(
                    leading: Icon(Icons.account_balance),
                    title: Text('基金追踪'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'risk_control',
                  child: ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('风控管理'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cron_task',
                  child: ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('定时任务'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'kline_pattern',
                  child: ListTile(
                    leading: Icon(Icons.auto_graph),
                    title: Text('K线形态识别'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'tdx_deep',
                  child: ListTile(
                    leading: Icon(Icons.data_exploration),
                    title: Text('TDX深度数据'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'mcp_server',
                  child: ListTile(
                    leading: Icon(Icons.dns_outlined),
                    title: Text('MCP服务管理'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'calendar',
                  child: ListTile(
                    leading: Icon(Icons.calendar_month),
                    title: Text('交易日历'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
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
