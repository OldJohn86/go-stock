import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/radar_api.dart';
import 'sector_stock_list_page.dart';

/// 行情雷达页面
/// 涨停热点、行业涨幅排名、资金流向、热门股票
class MarketRadarPage extends ConsumerStatefulWidget {
  const MarketRadarPage({super.key});

  @override
  ConsumerState<MarketRadarPage> createState() => _MarketRadarPageState();
}

class _MarketRadarPageState extends ConsumerState<MarketRadarPage>
    with SingleTickerProviderStateMixin {
  final RadarApi _radarApi = RadarApi();
  late TabController _tabController;

  Map<String, dynamic>? _radarData;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await _radarApi.getOverview();
    if (mounted) {
      setState(() {
        _radarData = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行情雷达'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '涨停热点'),
            Tab(text: '行业涨幅'),
            Tab(text: '资金流向'),
            Tab(text: '热门股票'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUplimitHotTab(),
                _buildIndustryRankTab(),
                _buildMoneyFlowTab(),
                _buildHotStocksTab(),
              ],
            ),
    );
  }

  // ===== 涨停热点 Tab =====

  Widget _buildUplimitHotTab() {
    final uplimitHot = _radarData?['uplimitHot'] as Map<String, dynamic>?;
    if (uplimitHot == null) {
      return _buildEmpty('暂无涨停热点数据');
    }

    final data = uplimitHot['data'] as Map<String, dynamic>?;
    if (data == null) {
      return _buildEmpty('暂无数据');
    }

    // 涨停个股列表
    final stocks = data['stocks'] as List<dynamic>?;
    if (stocks == null || stocks.isEmpty) {
      return _buildEmpty('今日暂无涨停');
    }

    // 涨停概况
    final summary = data['summary'] as Map<String, dynamic>?;
    final limitUpCount = summary?['limitUpCount'] ?? stocks.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 涨停概况卡片
          if (summary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _summaryChip('涨停', '$limitUpCount 只', Colors.red),
                    const SizedBox(width: 16),
                    _summaryChip('封板率', '${summary['sealRate'] ?? '-'}%', Colors.orange),
                    const SizedBox(width: 16),
                    _summaryChip('连板数', '${summary['maxConsecutive'] ?? '-'}', Colors.blue),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 涨停个股列表
          ...stocks.map((s) => _buildStockRankItem(s as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ===== 行业涨幅 Tab =====

  Widget _buildIndustryRankTab() {
    final industryRank = _radarData?['industryRank'] as Map<String, dynamic>?;
    if (industryRank == null) {
      return _buildEmpty('暂无行业涨幅数据');
    }

    final data = industryRank['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) {
      return _buildEmpty('暂无数据');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: data.length,
        itemBuilder: (_, i) {
          final item = data[i] as Map<String, dynamic>;
          final name = item['name'] ?? item['industryName'] ?? '-';
          final changePct = (item['changePct'] as num?)?.toDouble() ??
              (item['averatio'] as num?)?.toDouble() ?? 0;
          final isUp = changePct >= 0;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: Text(
                '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isUp ? Colors.red : Colors.green,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SectorStockListPage(sectorName: name, sectorType: 'industry'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== 资金流向 Tab =====

  Widget _buildMoneyFlowTab() {
    final moneyIn = _radarData?['moneyInTop'] as List<dynamic>? ?? [];
    final moneyOut = _radarData?['moneyOutTop'] as List<dynamic>? ?? [];

    if (moneyIn.isEmpty && moneyOut.isEmpty) {
      return _buildEmpty('暂无资金流向数据');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 净流入 TOP
          if (moneyIn.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.trending_up, size: 18, color: Colors.red),
                  const SizedBox(width: 6),
                  Text('主力净流入 TOP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < moneyIn.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildMoneyFlowItem(moneyIn[i] as Map<String, dynamic>, i),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 净流出 TOP
          if (moneyOut.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.trending_down, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('主力净流出 TOP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < moneyOut.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildMoneyFlowItem(moneyOut[i] as Map<String, dynamic>, i),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoneyFlowItem(Map<String, dynamic> item, int index) {
    final name = item['name'] ?? '-';
    final code = item['code'] ?? '';
    final netAmount = (item['netamount'] as num?)?.toDouble() ?? 0;
    final changePct = (item['changepercent'] as num?)?.toDouble() ?? 0;
    final isPositive = netAmount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('${index + 1}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (code.isNotEmpty)
                  Text('$code', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${_formatMoney(netAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isPositive ? Colors.red : Colors.green,
                ),
              ),
              Text(
                '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: changePct >= 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 热门股票 Tab =====

  Widget _buildHotStocksTab() {
    final hotStocks = _radarData?['hotStocks'] as List<dynamic>? ?? [];
    if (hotStocks.isEmpty) {
      return _buildEmpty('暂无热门股票数据');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: hotStocks.length,
        itemBuilder: (_, i) {
          final item = hotStocks[i] as Map<String, dynamic>;
          final stockData = item['data'] as Map<String, dynamic>? ?? item;
          final name = stockData['name'] ?? stockData['stockName'] ?? '-';
          final code = stockData['code'] ?? stockData['stockCode'] ?? '';
          final price = (stockData['current'] as num?)?.toDouble() ??
              (stockData['price'] as num?)?.toDouble() ?? 0;
          final changePct = (stockData['percent'] as num?)?.toDouble() ??
              (stockData['changePercent'] as num?)?.toDouble() ?? 0;
          final isUp = changePct >= 0;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isUp ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                radius: 16,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isUp ? Colors.red : Colors.green,
                  ),
                ),
              ),
              title: Text('$name',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('$code'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price > 0 ? price.toStringAsFixed(2) : '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isUp ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockRankItem(Map<String, dynamic> item) {
    final name = item['name'] ?? item['stockName'] ?? '-';
    final code = item['code'] ?? item['stockCode'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final changePct = (item['changePct'] as num?)?.toDouble() ??
        (item['changePercent'] as num?)?.toDouble() ?? 0;
    final isUp = changePct >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$code'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price > 0 ? price.toStringAsFixed(2) : '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isUp ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
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
}
