import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/fund_api.dart';

/// 基金详情页（基本信息 + 持仓 + 历史净值 + K线）
class FundDetailPage extends ConsumerStatefulWidget {
  final String fundCode;
  final String fundName;

  const FundDetailPage({super.key, required this.fundCode, required this.fundName});

  @override
  ConsumerState<FundDetailPage> createState() => _FundDetailPageState();
}

class _FundDetailPageState extends ConsumerState<FundDetailPage>
    with SingleTickerProviderStateMixin {
  final _api = FundApi();
  late final TabController _tabController;

  // Basic info
  Map<String, dynamic>? _basic;
  bool _basicLoading = true;

  // Holdings
  List<Map<String, dynamic>> _holdings = [];
  bool _holdingsLoading = true;

  // History
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadBasic();
    _loadHoldings();
    _loadHistory();
  }

  Future<void> _loadBasic() async {
    try {
      final data = await _api.getBasic(widget.fundCode);
      if (mounted) setState(() => _basic = data);
    } catch (_) {}
    if (mounted) setState(() => _basicLoading = false);
  }

  Future<void> _loadHoldings() async {
    try {
      final data = await _api.getHoldings(widget.fundCode);
      if (mounted) setState(() => _holdings = data);
    } catch (_) {}
    if (mounted) setState(() => _holdingsLoading = false);
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.getHistory(widget.fundCode, pageSize: 30);
      if (mounted) setState(() => _history = data);
    } catch (_) {}
    if (mounted) setState(() => _historyLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.fundName, style: const TextStyle(fontSize: 16)),
          Text(widget.fundCode, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        centerTitle: true,
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: '概况'), Tab(text: '持仓'), Tab(text: '净值'),
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildBasicTab(colorScheme),
        _buildHoldingsTab(colorScheme),
        _buildHistoryTab(colorScheme),
      ]),
    );
  }

  Widget _buildBasicTab(ColorScheme colorScheme) {
    if (_basicLoading) return const Center(child: CircularProgressIndicator());
    if (_basic == null) return const Center(child: Text('暂无数据'));

    final b = _basic!;
    final type = (b['type'] as String?) ?? '';
    final fullName = (b['fullName'] as String?) ?? '';
    final company = (b['company'] as String?) ?? '';
    final manager = (b['manager'] as String?) ?? '';
    final establishment = (b['establishment'] as String?) ?? '';
    final scale = (b['scale'] as String?) ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InfoRow(label: '基金全称', value: fullName),
        _InfoRow(label: '基金类型', value: type),
        _InfoRow(label: '基金公司', value: company),
        _InfoRow(label: '基金经理', value: manager),
        _InfoRow(label: '成立日期', value: establishment),
        _InfoRow(label: '基金规模', value: scale),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: _loadAll, child: const Text('刷新数据'))),
      ]),
    );
  }

  Widget _buildHoldingsTab(ColorScheme colorScheme) {
    if (_holdingsLoading) return const Center(child: CircularProgressIndicator());
    if (_holdings.isEmpty) return const Center(child: Text('暂无持仓数据'));

    return RefreshIndicator(
      onRefresh: _loadHoldings,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _holdings.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              _HeaderCell('排名', flex: 1),
              _HeaderCell('股票名称', flex: 3),
              _HeaderCell('占比', flex: 2),
              _HeaderCell('涨跌幅', flex: 2),
            ]),
          );
          }
          final item = _holdings[index - 1];
          final rank = (item['rank'] as num?)?.toInt() ?? index;
          final stockName = (item['stockName'] as String?) ?? '';
          final ratio = (item['ratio'] as num?)?.toDouble() ?? 0;
          final changeRate = (item['changeRate'] as num?)?.toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              _DataCell(rank.toString(), flex: 1),
              _DataCell(stockName, flex: 3, bold: true),
              _DataCell('${ratio.toStringAsFixed(2)}%', flex: 2),
              _DataCell(
                changeRate != null ? '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(2)}%' : '-',
                flex: 2,
                color: changeRate != null ? (changeRate >= 0 ? Colors.red : Colors.green) : null,
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab(ColorScheme colorScheme) {
    if (_historyLoading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) return const Center(child: Text('暂无净值数据'));

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _history.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              _HeaderCell('日期', flex: 3),
              _HeaderCell('单位净值', flex: 3),
              _HeaderCell('累计净值', flex: 3),
              _HeaderCell('日增长', flex: 2),
            ]),
          );
          }
          final item = _history[index - 1];
          final date = (item['date'] as String?) ?? '';
          final netValue = (item['netValue'] as num?)?.toDouble();
          final accumValue = (item['accumValue'] as num?)?.toDouble();
          final dailyGrowth = (item['dailyGrowth'] as num?)?.toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              _DataCell(date.length >= 10 ? date.substring(5) : date, flex: 3),
              _DataCell(netValue?.toStringAsFixed(4) ?? '-', flex: 3),
              _DataCell(accumValue?.toStringAsFixed(4) ?? '-', flex: 3),
              _DataCell(
                dailyGrowth != null ? '${dailyGrowth >= 0 ? '+' : ''}${dailyGrowth.toStringAsFixed(2)}%' : '-',
                flex: 2,
                color: dailyGrowth != null ? (dailyGrowth >= 0 ? Colors.red : Colors.green) : null,
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)));
  }
}

class _DataCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool bold;
  final Color? color;
  const _DataCell(this.label, {required this.flex, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w500 : null, color: color)));
  }
}
