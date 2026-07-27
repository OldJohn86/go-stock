import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dashboard_api.dart';
import '../api/monitor_api.dart';
import '../widgets/index_bar.dart';
import 'sector_stock_list_page.dart';

/// 大盘仪表盘页面
/// 整合：市场情绪、板块资金流向、投资组合概览、预警监控状态
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final DashboardApi _dashboardApi = DashboardApi();
  final MonitorApi _monitorApi = MonitorApi();

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _portfolio;
  bool _overviewLoading = true;
  bool _portfolioLoading = true;
  bool _monitorRunning = false;
  String? _portfolioError;
  int _tabIndex = 0; // 0=市场概览, 1=投资组合

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMonitorStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadOverview();
    _loadPortfolio();
  }

  Future<void> _loadOverview() async {
    final overview = await _dashboardApi.getOverview();
    if (mounted) {
      setState(() {
        _overview = overview;
        _overviewLoading = false;
      });
    }
  }

  Future<void> _loadPortfolio() async {
    try {
      final portfolio = await _dashboardApi.getPortfolio();
      if (mounted) {
        setState(() {
          _portfolio = portfolio;
          _portfolioLoading = false;
          _portfolioError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _portfolioLoading = false;
          _portfolioError = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _loadMonitorStatus() async {
    final status = await _monitorApi.getMonitorStatus();
    if (mounted && status != null) {
      setState(() {
        _monitorRunning = status['running'] == true;
      });
    }
  }

  Future<void> _toggleMonitor() async {
    final ok = _monitorRunning
        ? await _monitorApi.stopMonitor()
        : await _monitorApi.startMonitor();
    if (ok) {
      _loadMonitorStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
          _loadMonitorStatus();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('大盘仪表盘'),
              floating: true,
              snap: true,
              actions: [
                // 预警监控开关
                IconButton(
                  icon: Icon(
                    Icons.notifications_active,
                    color: _monitorRunning ? Colors.orange : null,
                  ),
                  tooltip: _monitorRunning ? '预警监控运行中' : '预警监控已停止',
                  onPressed: _toggleMonitor,
                ),
              ],
            ),
            // 大盘指数栏
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: IndexBar(key: UniqueKey()),
              ),
            ),
            // Tab 切换
            SliverToBoxAdapter(
              child: _buildTabBar(),
            ),
            // 内容
            if (_tabIndex == 0) ..._buildOverviewSlivers(),
            if (_tabIndex == 1) ..._buildPortfolioSlivers(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _tabButton('市场概览', 0),
          const SizedBox(width: 8),
          _tabButton('投资组合', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ===== 市场概览 Tab =====

  List<Widget> _buildOverviewSlivers() {
    if (_overviewLoading) {
      return [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_overview == null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('加载失败', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _overviewLoading = true);
                    _loadOverview();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      // 市场情绪卡片
      SliverToBoxAdapter(child: _buildMarketSentimentCard()),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      // 行业资金流向
      SliverToBoxAdapter(child: _buildSectionTitle('行业资金流向 TOP 10')),
      ..._buildIndustryMoneyRank(),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      // 概念资金流向
      SliverToBoxAdapter(child: _buildSectionTitle('概念资金流向 TOP 5')),
      ..._buildConceptMoneyRank(),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      // 全球指数
      SliverToBoxAdapter(child: _buildSectionTitle('全球主要指数')),
      ..._buildGlobalIndexes(),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildMarketSentimentCard() {
    final stat = _overview?['marketStat'] as Map<String, dynamic>?;
    if (stat == null) return const SizedBox.shrink();

    final upCount = stat['upCount'] ?? 0;
    final downCount = stat['downCount'] ?? 0;
    final limitUp = stat['limitUp'] ?? 0;
    final limitDown = stat['limitDown'] ?? 0;
    final sentiment = stat['sentimentDesc'] ?? '-';
    final upRatio = (stat['upRatio'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 20),
                const SizedBox(width: 8),
                Text('市场情绪', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _sentimentColor(sentiment).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$sentiment',
                    style: TextStyle(
                      color: _sentimentColor(sentiment),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 涨跌家数
            Row(
              children: [
                _statItem('上涨', '$upCount', Colors.red),
                const SizedBox(width: 16),
                _statItem('下跌', '$downCount', Colors.green),
                const SizedBox(width: 16),
                _statItem('涨跌比', '${upRatio.toStringAsFixed(1)}%', Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
            // 涨跌停
            Row(
              children: [
                _statItem('涨停', '$limitUp', Colors.red),
                const SizedBox(width: 16),
                _statItem('跌停', '$limitDown', Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            // 涨跌比进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: upRatio / 100,
                backgroundColor: Colors.green.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.withValues(alpha: 0.7)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '上涨占比 ${upRatio.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _sentimentColor(String sentiment) {
    if (sentiment.contains('强') || sentiment.contains('涨')) return Colors.red;
    if (sentiment.contains('弱') || sentiment.contains('跌') || sentiment.contains('冰')) return Colors.green;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildIndustryMoneyRank() {
    final list = _overview?['industryMoneyRank'] as List<dynamic>? ?? [];
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildMoneyRankItem(list[i] as Map<String, dynamic>, i, 'industry'),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildConceptMoneyRank() {
    final list = _overview?['conceptMoneyRank'] as List<dynamic>? ?? [];
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildMoneyRankItem(list[i] as Map<String, dynamic>, i, 'concept'),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildMoneyRankItem(Map<String, dynamic> item, int index, String type) {
    final name = item['name'] ?? '-';
    final netAmount = (item['netamount'] as num?)?.toDouble() ?? 0;
    final changePercent = (item['changepercent'] as num?)?.toDouble() ?? 0;
    final isPositive = netAmount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SectorStockListPage(sectorName: name, sectorType: type),
          ),
        ),
        child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('$name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatMoney(netAmount),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPositive ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: changePercent >= 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatMoney(double value) {
    final abs = value.abs();
    if (abs >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(2)}亿';
    } else if (abs >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return value.toStringAsFixed(0);
  }

  List<Widget> _buildGlobalIndexes() {
    final list = _overview?['globalIndexes'] as List<dynamic>? ?? [];
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final item in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _buildGlobalIndexItem(item as Map<String, dynamic>),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildGlobalIndexItem(Map<String, dynamic> item) {
    final name = item['name'] ?? '-';
    final zxj = item['zxj'] ?? '-';
    final zdf = item['zdf'] ?? '0';
    final zdfStr = '$zdf';
    final isUp = !zdfStr.startsWith('-') && zdfStr != '0' && zdfStr != '0.00';

    return Row(
      children: [
        Expanded(
          child: Text('$name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 12),
        Text('$zxj', style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            '${isUp ? '+' : ''}$zdf%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isUp ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  // ===== 投资组合 Tab =====

  List<Widget> _buildPortfolioSlivers() {
    if (_portfolioLoading) {
      return [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_portfolioError != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(_portfolioError!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _portfolioLoading = true;
                      _portfolioError = null;
                    });
                    _loadPortfolio();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      // 总资产卡片
      SliverToBoxAdapter(child: _buildPortfolioSummaryCard()),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      // 持仓列表
      SliverToBoxAdapter(child: _buildSectionTitle('持仓明细')),
      ..._buildPositionList(),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildPortfolioSummaryCard() {
    if (_portfolio == null) return const SizedBox.shrink();

    final totalAssets = (_portfolio!['totalAssets'] as num?)?.toDouble() ?? 0;
    final totalPnL = (_portfolio!['totalPnL'] as num?)?.toDouble() ?? 0;
    final totalPnLPct = (_portfolio!['totalPnLPct'] as num?)?.toDouble() ?? 0;
    final cash = (_portfolio!['cash'] as num?)?.toDouble() ?? 0;
    final investedCapital = (_portfolio!['investedCapital'] as num?)?.toDouble() ?? 0;
    final winCount = (_portfolio!['winCount'] as num?)?.toInt() ?? 0;
    final loseCount = (_portfolio!['loseCount'] as num?)?.toInt() ?? 0;

    final isPositive = totalPnL >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('总资产', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '¥${_formatNumber(totalAssets)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryItem('持仓盈亏', '¥${_formatNumber(totalPnL)}', isPositive ? Colors.red : Colors.green),
                const SizedBox(width: 24),
                _summaryItem('盈亏比例', '${isPositive ? '+' : ''}${totalPnLPct.toStringAsFixed(2)}%', isPositive ? Colors.red : Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryItem('已投入', '¥${_formatNumber(investedCapital)}', Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 24),
                _summaryItem('可用现金', '¥${_formatNumber(cash)}', Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryItem('盈利持仓', '$winCount 只', Colors.red),
                const SizedBox(width: 24),
                _summaryItem('亏损持仓', '$loseCount 只', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPositionList() {
    final positions = _portfolio?['positions'] as List<dynamic>? ?? [];
    if (positions.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('暂无持仓', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final pos = positions[index] as Map<String, dynamic>;
            final position = pos['position'] as Map<String, dynamic>? ?? {};
            final stockName = position['stockName'] ?? position['stockCode'] ?? '-';
            final stockCode = position['stockCode'] ?? '';
            final quantity = (position['quantity'] as num?)?.toInt() ?? 0;
            final costPrice = (position['costPrice'] as num?)?.toDouble() ?? 0;
            final currentPrice = (pos['currentPrice'] as num?)?.toDouble() ?? 0;
            final pnlPct = (pos['pnlPct'] as num?)?.toDouble() ?? 0;
            final pnlAmount = (pos['pnlAmount'] as num?)?.toDouble() ?? 0;
            final positionPct = (pos['positionPct'] as num?)?.toDouble() ?? 0;

            final isPositive = pnlPct >= 0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$stockName',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              Text(
                                '$stockCode  |  $quantity股',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isPositive ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isPositive ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(
                              '${isPositive ? '+' : ''}¥${_formatNumber(pnlAmount)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isPositive ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('成本 $costPrice', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Text('现价 $currentPrice', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Text('仓位 ${positionPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: positions.length,
        ),
      ),
    ];
  }

  String _formatNumber(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(2)}万';
    }
    return value.toStringAsFixed(2);
  }
}
