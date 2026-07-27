import 'package:flutter/material.dart';
import '../api/risk_api.dart';

/// 风控管理页面
class RiskControlPage extends StatefulWidget {
  const RiskControlPage({super.key});

  @override
  State<RiskControlPage> createState() => _RiskControlPageState();
}

class _RiskControlPageState extends State<RiskControlPage> {
  final _api = RiskApi();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _portfolioData;
  Map<String, dynamic>? _riskReport;
  List<dynamic> _positions = [];
  List<dynamic> _recentTrades = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getPositions(),
        _api.getRiskReport(),
        _api.getRecentTrades(),
      ]);
      if (!mounted) return;
      setState(() {
        _portfolioData = results[0] as Map<String, dynamic>?;
        _riskReport = results[1] as Map<String, dynamic>?;
        _recentTrades = results[2] as List<dynamic>;
        _positions = _portfolioData?['positions'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '请求失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _deletePosition(int id) async {
    final ok = await _api.deletePosition(id);
    if (ok) {
      _loadData();
    }
  }

  void _showAddPositionDialog() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final stopLossCtrl = TextEditingController(text: '-8');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增持仓'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: '股票代码', hintText: '600519.SH')),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '股票名称')),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: '成本价'), keyboardType: TextInputType.number),
              TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: '持仓数量'), keyboardType: TextInputType.number),
              TextField(controller: stopLossCtrl, decoration: const InputDecoration(labelText: '止损(%)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final ok = await _api.addPosition({
                'stockCode': codeCtrl.text,
                'stockName': nameCtrl.text,
                'costPrice': double.tryParse(priceCtrl.text) ?? 0,
                'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                'stopLossPct': double.tryParse(stopLossCtrl.text) ?? -8,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (ok) _loadData();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('风控管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddPositionDialog, tooltip: '新增持仓'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: '刷新'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 12),
          _buildRiskReport(),
          const SizedBox(height: 12),
          _buildPositionsList(),
          const SizedBox(height: 12),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPnL = (_portfolioData?['totalPnL'] as num?)?.toDouble() ?? 0;
    final totalPnLPct = (_portfolioData?['totalPnLPct'] as num?)?.toDouble() ?? 0;
    final totalAssets = (_portfolioData?['totalAssets'] as num?)?.toDouble() ?? 0;
    final totalMarketValue = (_portfolioData?['totalMarketValue'] as num?)?.toDouble() ?? 0;
    final cash = (_portfolioData?['cash'] as num?)?.toDouble() ?? 0;
    final winCount = (_portfolioData?['winCount'] as int?) ?? 0;
    final loseCount = (_portfolioData?['loseCount'] as int?) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('总资产', '¥${_fmt(totalAssets)}', Colors.blue),
                ),
                Expanded(
                  child: _buildStatItem('持仓市值', '¥${_fmt(totalMarketValue)}', Colors.orange),
                ),
                Expanded(
                  child: _buildStatItem('可用现金', '¥${_fmt(cash)}', Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '累计盈亏',
                    '${totalPnL >= 0 ? "+" : ""}${_fmt(totalPnL)}',
                    totalPnL >= 0 ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '收益率',
                    '${totalPnLPct >= 0 ? "+" : ""}${totalPnLPct.toStringAsFixed(2)}%',
                    totalPnLPct >= 0 ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem('胜率', '${_positions.isEmpty ? 0 : (winCount * 100 ~/ (winCount + loseCount))}%', Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildRiskReport() {
    if (_riskReport == null || _riskReport!.isEmpty) return const SizedBox.shrink();
    final score = _riskReport!['score'] ?? _riskReport!['Score'];
    final level = _riskReport!['level'] as String? ?? '';
    final items = _riskReport!['items'] as List<dynamic>? ?? [];

    Color levelColor;
    String levelText;
    switch (level) {
      case 'low':
        levelColor = Colors.green;
        levelText = '低风险';
      case 'medium':
        levelColor = Colors.orange;
        levelText = '中风险';
      case 'high':
        levelColor = Colors.red;
        levelText = '高风险';
      default:
        levelColor = Colors.grey;
        levelText = '未知';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('风控评分', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$score/100', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: levelColor)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(levelText, style: TextStyle(color: levelColor, fontSize: 12)),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(),
              ...items.take(5).map((item) {
                final m = item is Map<String, dynamic> ? item : {};
                final desc = m['description'] ?? m['detail'] ?? m['name'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Expanded(child: Text('$desc', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPositionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('持仓列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddPositionDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增'),
            ),
          ],
        ),
        if (_positions.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('暂无持仓', style: TextStyle(color: Colors.grey))))
        else
          ..._positions.map((pos) => _buildPositionCard(pos is Map<String, dynamic> ? pos : {})),
      ],
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> pos) {
    final position = pos['position'] as Map<String, dynamic>? ?? pos;
    final stockCode = position['stockCode'] as String? ?? pos['stockCode'] as String? ?? '';
    final stockName = position['stockName'] as String? ?? pos['stockName'] as String? ?? '';
    final costPrice = (position['costPrice'] as num?)?.toDouble() ?? (pos['costPrice'] as num?)?.toDouble() ?? 0;
    final quantity = (position['quantity'] as num?)?.toInt() ?? (pos['quantity'] as num?)?.toInt() ?? 0;
    final id = (position['id'] as num?)?.toInt() ?? (pos['id'] as num?)?.toInt() ?? 0;

    final currentPrice = (pos['currentPrice'] as num?)?.toDouble() ?? costPrice;
    final pnlAmount = (pos['pnlAmount'] as num?)?.toDouble() ?? (pos['PnLAmount'] as num?)?.toDouble() ?? 0;
    final pnlPct = (pos['pnlPct'] as num?)?.toDouble() ?? (pos['PnLPct'] as num?)?.toDouble() ?? 0;

    final marketValue = currentPrice * quantity;
    final isProfitable = pnlAmount >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(stockCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 6),
                Text(stockName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _deletePosition(id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Colors.red[300],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('成本: ${_fmt(costPrice)}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('现价: ${_fmt(currentPrice)}', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('数量: $quantity', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('盈亏: ', style: const TextStyle(fontSize: 12)),
                Text(
                  '${isProfitable ? "+" : ""}${_fmt(pnlAmount)} (${pnlPct >= 0 ? "+" : ""}${pnlPct.toStringAsFixed(2)}%)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isProfitable ? Colors.red : Colors.green),
                ),
                const Spacer(),
                Text('市值: ${_fmt(marketValue)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('近期交易', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (_recentTrades.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('暂无交易记录', style: TextStyle(color: Colors.grey))))
        else
          ..._recentTrades.take(10).map((t) {
            final m = t is Map<String, dynamic> ? t : {};
            final code = m['stockCode'] as String? ?? '';
            final name = m['stockName'] as String? ?? '';
            final type = m['type'] as String? ?? '';
            final price = (m['price'] as num?)?.toDouble() ?? 0;
            final qty = (m['quantity'] as num?)?.toInt() ?? 0;
            final date = m['tradeDate'] as String? ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (type == 'buy' ? Colors.red : Colors.green).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type == 'buy' ? '买入' : '卖出', style: TextStyle(fontSize: 11, color: type == 'buy' ? Colors.red : Colors.green)),
                ),
                title: Text('$code $name', style: const TextStyle(fontSize: 13)),
                subtitle: Text('$date  价格: ${_fmt(price)}  数量: $qty', style: const TextStyle(fontSize: 11)),
              ),
            );
          }),
      ],
    );
  }

  String _fmt(num? v) {
    if (v == null) return '--';
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}
