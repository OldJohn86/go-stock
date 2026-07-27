import 'package:flutter/material.dart';

import '../api/market_api.dart';
import '../widgets/price_change.dart';
import 'sector_stock_list_page.dart';

/// 板块行情页（行业资金流 + 概念资金流 + 行业估值）
class SectorRankingPage extends StatefulWidget {
  const SectorRankingPage({super.key});

  @override
  State<SectorRankingPage> createState() => _SectorRankingPageState();
}

class _SectorRankingPageState extends State<SectorRankingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = MarketApi();

  // 行业资金流
  List<Map<String, dynamic>> _industryMoney = [];
  bool _industryLoading = true;

  // 行业估值
  List<Map<String, dynamic>> _industryValuation = [];
  bool _valuationLoading = true;

  // 概念资金流
  List<Map<String, dynamic>> _conceptFlow = [];
  bool _conceptLoading = true;

  // 排序方式
  String _sortBy = 'netamount'; // netamount, inflow, outflow

  /// API 可能返回 String 或 num，统一转 double
  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadIndustryMoney();
    _loadIndustryValuation();
    _loadConceptFlow();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_industryMoney.isEmpty) _loadIndustryMoney();
          break;
        case 1:
          if (_industryValuation.isEmpty) _loadIndustryValuation();
          break;
        case 2:
          if (_conceptFlow.isEmpty) _loadConceptFlow();
          break;
      }
    }
  }

  Future<void> _loadIndustryMoney() async {
    setState(() => _industryLoading = true);
    final data = await _api.getIndustryMoneyRank(fenlei: 0, sort: _sortBy);
    if (mounted) {
      setState(() {
        _industryMoney = data;
        _industryLoading = false;
      });
    }
  }

  Future<void> _loadIndustryValuation() async {
    setState(() => _valuationLoading = true);
    final data = await _api.getIndustryValuation();
    if (mounted) {
      setState(() {
        _industryValuation = data;
        _valuationLoading = false;
      });
    }
  }

  Future<void> _loadConceptFlow() async {
    setState(() => _conceptLoading = true);
    final data = await _api.getConceptFundFlowRank(topN: 30);
    if (mounted) {
      setState(() {
        _conceptFlow = data;
        _conceptLoading = false;
      });
    }
  }

  void _showSortPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('排序方式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.trending_down),
              title: const Text('按净流入排序'),
              trailing: _sortBy == 'netamount' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _sortBy = 'netamount');
                _loadIndustryMoney();
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('按流入资金排序'),
              trailing: _sortBy == 'inflow' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _sortBy = 'inflow');
                _loadIndustryMoney();
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('按流出资金排序'),
              trailing: _sortBy == 'outflow' ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _sortBy = 'outflow');
                _loadIndustryMoney();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('板块行情'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '行业资金流'),
            Tab(text: '行业估值'),
            Tab(text: '概念资金流'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: '排序',
              onPressed: _showSortPicker,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIndustryMoneyTab(theme),
          _buildIndustryValuationTab(theme),
          _buildConceptFlowTab(theme),
        ],
      ),
    );
  }

  Widget _buildIndustryMoneyTab(ThemeData theme) {
    if (_industryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_industryMoney.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    return RefreshIndicator(
      onRefresh: _loadIndustryMoney,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _industryMoney.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final item = _industryMoney[i];
          final name = item['name'] as String? ?? item['plateName'] as String? ?? '';
          final changePercent = _parseDouble(item['changePercent']);
          final netAmount = _parseDouble(item['netamount']);

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectorStockListPage(sectorName: name, sectorType: 'industry'),
              ),
            ),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i < 3 ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  flex: 2,
                  child: PriceChange(
                    change: 0,
                    changePercent: changePercent / 100.0,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatFundFlow(netAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: netAmount >= 0 ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
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

  Widget _buildIndustryValuationTab(ThemeData theme) {
    if (_valuationLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_industryValuation.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    return RefreshIndicator(
      onRefresh: _loadIndustryValuation,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _industryValuation.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final item = _industryValuation[i];
          final name = item['name'] as String? ?? '';
          final pe = _parseDouble(item['pe']);
          final pb = _parseDouble(item['pb']);

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectorStockListPage(sectorName: name, sectorType: 'industry'),
              ),
            ),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    pe > 0 ? pe.toStringAsFixed(1) : '-',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    pb > 0 ? pb.toStringAsFixed(1) : '-',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
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

  Widget _buildConceptFlowTab(ThemeData theme) {
    if (_conceptLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conceptFlow.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    return RefreshIndicator(
      onRefresh: _loadConceptFlow,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _conceptFlow.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final item = _conceptFlow[i];
          final name = item['conceptName'] as String? ?? item['name'] as String? ?? '';
          final netAmount = _parseDouble(item['netAmount']);
          final leaderStock = item['leaderStock'] as String? ?? '';

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SectorStockListPage(sectorName: name, sectorType: 'concept'),
              ),
            ),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: i < 3 ? theme.colorScheme.primary : theme.disabledColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      if (leaderStock.isNotEmpty)
                        Text(
                          '龙头: $leaderStock',
                          style: TextStyle(fontSize: 11, color: theme.disabledColor),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatFundFlow(netAmount),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: netAmount >= 0 ? Colors.red : Colors.green,
                      fontSize: 13,
                    ),
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

  String _formatFundFlow(double value) {
    if (value.abs() >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return value.toStringAsFixed(0);
  }
}
