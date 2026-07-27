import 'dart:async';

import 'package:flutter/material.dart';
import '../api/dashboard_api.dart';

/// 日内 T+0 / 做T 提醒页面
/// 显示持仓成本 vs 现价，计算做T空间
class T0TradePage extends StatefulWidget {
  const T0TradePage({super.key});

  @override
  State<T0TradePage> createState() => _T0TradePageState();
}

class _T0TradePageState extends State<T0TradePage> {
  final DashboardApi _dashboardApi = DashboardApi();

  Map<String, dynamic>? _portfolio;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), _loadData);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData([Timer? _]) async {
    try {
      final portfolio = await _dashboardApi.getPortfolio();
      if (mounted) {
        setState(() {
          _portfolio = portfolio;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('日内做T提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.disabledColor)),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: _buildBody(theme),
                ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final positions = _portfolio?['positions'] as List<dynamic>? ?? [];
    if (positions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('暂无持仓', style: TextStyle(color: theme.disabledColor, fontSize: 16)),
            const SizedBox(height: 8),
            Text('添加交易记录后可查看做T机会', style: TextStyle(color: theme.disabledColor, fontSize: 13)),
          ],
        ),
      );
    }

    // 按做T空间排序（现价 - 成本价）
    final sortedPositions = List<Map<String, dynamic>>.from(positions.map((p) {
      final position = (p as Map<String, dynamic>)['position'] as Map<String, dynamic>? ?? {};
      final costPrice = (position['costPrice'] as num?)?.toDouble() ?? 0;
      final currentPrice = (p['currentPrice'] as num?)?.toDouble() ?? 0;
      final quantity = (position['quantity'] as num?)?.toInt() ?? 0;
      final spacePct = costPrice > 0 ? ((currentPrice - costPrice) / costPrice * 100) : 0.0;
      final t0Profit = (currentPrice - costPrice) * quantity;
      return {
        'position': position,
        'currentPrice': currentPrice,
        'costPrice': costPrice,
        'quantity': quantity,
        'spacePct': spacePct,
        't0Profit': t0Profit,
        'pnlPct': p['pnlPct'],
        'pnlAmount': p['pnlAmount'],
        'positionPct': p['positionPct'],
      };
    }));

    // 按T+0空间排序（优先展示空间大的）
    sortedPositions.sort((a, b) => (b['t0Profit'] as num).abs().compareTo((a['t0Profit'] as num).abs()));

    // 生成做T建议
    final suggestions = _generateTSuggestions(sortedPositions);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 做T机会概览
        if (suggestions.isNotEmpty) ...[
          _buildTSuggestionCard(theme, suggestions),
          const SizedBox(height: 12),
        ],
        // 持仓列表（含做T空间）
        Text('持仓明细', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...sortedPositions.map((pos) => _buildT0PositionCard(theme, pos)),
      ],
    );
  }

  List<Map<String, dynamic>> _generateTSuggestions(List<Map<String, dynamic>> positions) {
    final suggestions = <Map<String, dynamic>>[];
    for (final pos in positions) {
      final spacePct = (pos['spacePct'] as num).toDouble();
      final currentPrice = (pos['currentPrice'] as num).toDouble();
      final costPrice = (pos['costPrice'] as num).toDouble();
      final quantity = (pos['quantity'] as num).toInt();
      final position = pos['position'] as Map<String, dynamic>;
      final stockName = position['stockName'] ?? position['stockCode'] ?? '-';
      final stockCode = position['stockCode'] ?? '';

      // 正空间：现价 > 成本 → 适合先卖后买
      if (spacePct > 0.5) {
        final dropTarget = currentPrice * 0.97; // 回落3%接回

        suggestions.add({
          'type': 'sell_first',
          'stockName': stockName,
          'stockCode': stockCode,
          'action': '先卖后买',
          'price': currentPrice,
          'costPrice': costPrice,
          'targetPrice': dropTarget,
          'profitPerShare': dropTarget > 0 ? currentPrice - dropTarget : 0,
          'potentialProfit': (currentPrice - dropTarget) * quantity * 0.6, // 保守估计60%成交
          'quantity': quantity,
        });
      }

      // 负空间：现价 < 成本 → 适合先买后卖（做低成本）
      if (spacePct < -1 && currentPrice > 0) {
        final buyNowPrice = currentPrice;
        final beforeSellTarget = costPrice; // 回到成本价卖出
        final sharesToBuy = (quantity * 0.3).ceil(); // 买30%仓位做T

        suggestions.add({
          'type': 'buy_first',
          'stockName': stockName,
          'stockCode': stockCode,
          'action': '先买后卖',
          'price': buyNowPrice,
          'costPrice': costPrice,
          'targetPrice': beforeSellTarget,
          'profitPerShare': beforeSellTarget - buyNowPrice,
          'potentialProfit': (beforeSellTarget - buyNowPrice) * sharesToBuy * 0.5, // 保守
          'quantity': sharesToBuy,
        });
      }
    }

    // 按潜在收益排序
    suggestions.sort((a, b) => (b['potentialProfit'] as num).compareTo((a['potentialProfit'] as num)));
    return suggestions.take(3).toList();
  }

  Widget _buildTSuggestionCard(ThemeData theme, List<Map<String, dynamic>> suggestions) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text('做T机会', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${suggestions.length} 个机会',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < suggestions.length; i++) ...[
              if (i > 0) const Divider(height: 12),
              _buildSuggestionItem(theme, suggestions[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(ThemeData theme, Map<String, dynamic> s) {
    final isSellFirst = s['type'] == 'sell_first';
    final actionColor = isSellFirst ? Colors.red : Colors.green;
    final actionIcon = isSellFirst ? Icons.arrow_downward : Icons.arrow_upward;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(actionIcon, size: 16, color: actionColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['stockName']}  ${s['action']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '现价 ${s['price']}  目标 ${s['targetPrice']}  预计收益 ¥${_formatMoney((s['potentialProfit'] as num).toDouble())}',
                  style: TextStyle(fontSize: 11, color: theme.disabledColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '¥${_formatMoney((s['potentialProfit'] as num).toDouble())}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildT0PositionCard(ThemeData theme, Map<String, dynamic> pos) {
    final position = pos['position'] as Map<String, dynamic>;
    final stockName = position['stockName'] ?? position['stockCode'] ?? '-';
    final stockCode = position['stockCode'] ?? '';
    final quantity = (pos['quantity'] as num).toInt();
    final costPrice = (pos['costPrice'] as num).toDouble();
    final currentPrice = (pos['currentPrice'] as num).toDouble();
    final spacePct = (pos['spacePct'] as num).toDouble();
    final t0Profit = (pos['t0Profit'] as num).toDouble();
    final pnlPct = (pos['pnlPct'] as num?)?.toDouble() ?? 0;
    final positionPct = (pos['positionPct'] as num?)?.toDouble() ?? 0;

    final isAboveCost = currentPrice >= costPrice;
    final t0Amplitude = costPrice > 0 ? (currentPrice - costPrice).abs() / costPrice * 100 : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(stockCode, style: TextStyle(fontSize: 12, color: theme.disabledColor)),
                    ],
                  ),
                ),
                // T+0 空间标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (t0Amplitude > 2 ? Colors.orange : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '做T空间 ${spacePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: t0Amplitude > 2 ? Colors.orange : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 价格对比条
            Row(
              children: [
                // 成本价
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('成本价', style: TextStyle(fontSize: 11, color: theme.disabledColor)),
                      const SizedBox(height: 2),
                      Text(
                        costPrice.toStringAsFixed(3),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // 中间箭头指示
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Icon(
                        isAboveCost ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isAboveCost ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      Text(
                        '${spacePct >= 0 ? '+' : ''}${spacePct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAboveCost ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                // 现价
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('现价', style: TextStyle(fontSize: 11, color: theme.disabledColor)),
                      const SizedBox(height: 2),
                      Text(
                        currentPrice.toStringAsFixed(3),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAboveCost ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 底部信息行
            Row(
              children: [
                // T+0 收益潜力
                Text(
                  '做T收益潜力: ¥${_formatMoney(t0Profit)}  ',
                  style: TextStyle(fontSize: 12, color: isAboveCost ? Colors.red : Colors.green),
                ),
                Text(
                  '$quantity股  ${positionPct.toStringAsFixed(0)}%仓位',
                  style: TextStyle(fontSize: 12, color: theme.disabledColor),
                ),
                const Spacer(),
                // 涨跌幅
                Text(
                  '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: pnlPct >= 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            // 操作建议
            if (t0Amplitude > 1.5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAboveCost ? Colors.red : Colors.green).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isAboveCost ? Colors.red : Colors.green).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAboveCost ? Icons.sell : Icons.shopping_cart,
                        size: 14,
                        color: isAboveCost ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAboveCost
                            ? '建议：高抛低吸，现价高于成本 ${spacePct.toStringAsFixed(1)}%，可先卖后买'
                            : '建议：逢低补仓，现价低于成本 ${spacePct.abs().toStringAsFixed(1)}%，可先买后卖降低均价',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAboveCost ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(2)}万';
    }
    return value.toStringAsFixed(2);
  }
}
