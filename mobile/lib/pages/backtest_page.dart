import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api/backtest_api.dart';

/// 交易回测分析页 — 增强版（含图表可视化）
class BacktestPage extends StatefulWidget {
  const BacktestPage({super.key});

  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  final _api = BacktestApi();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      final data = await _api.getBacktestAnalysis();
      if (mounted) {
        if (data != null) {
          setState(() {
            _data = data;
            _loading = false;
          });
        } else {
          setState(() {
            _error = '暂无交易数据，请先添加交易记录';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('交易回测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                      Icon(Icons.bar_chart, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.disabledColor)),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(theme),
                        const SizedBox(height: 12),
                        _buildMetricsCard(theme),
                        const SizedBox(height: 16),
                        // 收益曲线图（新）
                        _buildEquityCurveSection(theme),
                        const SizedBox(height: 16),
                        // 月度盈亏柱状图（新）
                        _buildMonthlyChartSection(theme),
                        const SizedBox(height: 16),
                        // 盈亏分布饼图（新）
                        _buildPnLPieSection(theme),
                        const SizedBox(height: 16),
                        _buildStockStatsSection(theme),
                        const SizedBox(height: 16),
                        _buildMonthlyStatsSection(theme),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ===================== 收益曲线图 =====================

  Widget _buildEquityCurveSection(ThemeData theme) {
    // 从 monthlyStats 构建月度收益曲线
    final monthlyStats = _data?['monthlyStats'] as List<dynamic>? ?? [];
    if (monthlyStats.isEmpty) return const SizedBox();

    // 累计收益曲线
    final spots = <FlSpot>[];
    double cumulative = 0;
    for (int i = 0; i < monthlyStats.length; i++) {
      final m = monthlyStats[i] as Map<String, dynamic>;
      final profit = (m['profit'] as num?)?.toDouble() ?? 0;
      cumulative += profit;
      spots.add(FlSpot(i.toDouble(), cumulative));
    }

    final maxY = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final yRange = (maxY - minY).abs().clamp(1, double.infinity);
    final yPadding = yRange * 0.15;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('累计收益曲线', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yRange / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _formatShortMoney(value),
                              style: TextStyle(fontSize: 10, color: theme.disabledColor),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (monthlyStats.length / 4).ceilToDouble().clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= monthlyStats.length) return const SizedBox();
                          final m = monthlyStats[idx] as Map<String, dynamic>;
                          final month = m['month'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              month.length >= 7 ? month.substring(5) : month,
                              style: TextStyle(fontSize: 9, color: theme.disabledColor),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: minY - yPadding,
                  maxY: maxY + yPadding,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: cumulative >= 0 ? Colors.red : Colors.green,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length < 20,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: spot.y >= 0 ? Colors.red : Colors.green,
                            strokeWidth: 0,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (cumulative >= 0 ? Colors.red : Colors.green).withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        String label = '';
                        if (idx >= 0 && idx < monthlyStats.length) {
                          final m = monthlyStats[idx] as Map<String, dynamic>;
                          label = m['month'] as String? ?? '';
                        }
                        return LineTooltipItem(
                          '$label\n${_formatMoney(spot.y)}',
                          TextStyle(color: spot.y >= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== 月度盈亏柱状图 =====================

  Widget _buildMonthlyChartSection(ThemeData theme) {
    final monthlyStats = _data?['monthlyStats'] as List<dynamic>? ?? [];
    if (monthlyStats.isEmpty) return const SizedBox();

    // 找最大绝对值
    double maxAbs = 0;
    for (final m in monthlyStats) {
      final profit = (m as Map<String, dynamic>)['profit'] as num? ?? 0;
      maxAbs = maxAbs > profit.abs().toDouble() ? maxAbs : profit.abs().toDouble();
    }
    maxAbs = maxAbs.clamp(1, double.infinity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度盈亏', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxAbs,
                  minY: -maxAbs,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAbs / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatShortMoney(value),
                            style: TextStyle(fontSize: 9, color: theme.disabledColor),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= monthlyStats.length) return const SizedBox();
                          final m = monthlyStats[idx] as Map<String, dynamic>;
                          final month = m['month'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              month.length >= 7 ? month.substring(5) : month,
                              style: TextStyle(fontSize: 9, color: theme.disabledColor),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(monthlyStats.length, (i) {
                    final m = monthlyStats[i] as Map<String, dynamic>;
                    final profit = (m['profit'] as num?)?.toDouble() ?? 0;
                    final isUp = profit >= 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: profit,
                          color: isUp ? Colors.red : Colors.green,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(3)),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = monthlyStats[group.x] as Map<String, dynamic>;
                        final month = m['month'] as String? ?? '';
                        final trades = m['trades'] as int? ?? 0;
                        return BarTooltipItem(
                          '$month\n盈亏: ${_formatMoney(rod.toY)}\n交易: $trades 笔',
                          TextStyle(color: rod.toY >= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== 盈亏分布饼图 =====================

  Widget _buildPnLPieSection(ThemeData theme) {
    final winTrades = (_data?['winTrades'] as num?)?.toInt() ?? 0;
    final loseTrades = (_data?['loseTrades'] as num?)?.toInt() ?? 0;
    final totalTrades = winTrades + loseTrades;
    if (totalTrades == 0) return const SizedBox();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('盈亏分布', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: winTrades.toDouble(),
                            color: Colors.red,
                            radius: 40,
                            title: '${(winTrades / totalTrades * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          PieChartSectionData(
                            value: loseTrades.toDouble(),
                            color: Colors.green,
                            radius: 40,
                            title: '${(loseTrades / totalTrades * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem('盈利', winTrades, Colors.red),
                    const SizedBox(height: 10),
                    _legendItem('亏损', loseTrades, Colors.green),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label  $count 次', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  // ===================== 原有卡片（保留） =====================

  Widget _buildSummaryCard(ThemeData theme) {
    final totalProfit = (_data?['totalProfit'] as num?)?.toDouble() ?? 0;
    final winRate = (_data?['winRate'] as num?)?.toDouble() ?? 0;
    final totalTrades = (_data?['totalTrades'] as num?)?.toInt() ?? 0;
    final isProfit = totalProfit >= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isProfit ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text('总盈亏', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              '${isProfit ? '+' : ''}¥${_formatMoney(totalProfit.abs())}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: isProfit ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(theme, '总交易', '$totalTrades 笔'),
                _summaryItem(theme, '胜率', '${winRate.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: theme.disabledColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildMetricsCard(ThemeData theme) {
    final winTrades = (_data?['winTrades'] as num?)?.toInt() ?? 0;
    final loseTrades = (_data?['loseTrades'] as num?)?.toInt() ?? 0;
    final avgProfit = (_data?['avgProfit'] as num?)?.toDouble() ?? 0;
    final bestTrade = (_data?['bestTrade'] as num?)?.toDouble() ?? 0;
    final worstTrade = (_data?['worstTrade'] as num?)?.toDouble() ?? 0;
    final totalFees = (_data?['totalFees'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('详细指标', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _metricRow(theme, '盈利次数', '$winTrades 次', Colors.red),
            _metricRow(theme, '亏损次数', '$loseTrades 次', Colors.green),
            _metricRow(theme, '平均盈亏', _formatMoney(avgProfit), avgProfit >= 0 ? Colors.red : Colors.green),
            _metricRow(theme, '单笔最大盈利', _formatMoney(bestTrade), Colors.red),
            _metricRow(theme, '单笔最大亏损', _formatMoney(worstTrade.abs()), Colors.green),
            _metricRow(theme, '总手续费', _formatMoney(totalFees), theme.disabledColor),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(ThemeData theme, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatsSection(ThemeData theme) {
    final stockStats = _data?['stockStats'] as List<dynamic>? ?? [];
    if (stockStats.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('个股统计', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 2, child: Text('股票', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('交易', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('胜率', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('盈亏', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                ],
              ),
            ),
            ...stockStats.map((s) {
              final m = s as Map<String, dynamic>;
              final profit = (m['totalProfit'] as num?)?.toDouble() ?? 0;
              final winRate = (m['winRate'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['stockName'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(m['stockCode'] as String? ?? '', style: TextStyle(fontSize: 11, color: theme.disabledColor)),
                        ],
                      ),
                    ),
                    Expanded(flex: 1, child: Text('${m['sellCount'] ?? 0}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 1, child: Text(
                      '${winRate.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: winRate >= 50 ? Colors.red : Colors.green),
                    )),
                    Expanded(flex: 1, child: Text(
                      _formatMoney(profit),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: profit >= 0 ? Colors.red : Colors.green),
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsSection(ThemeData theme) {
    final monthlyStats = _data?['monthlyStats'] as List<dynamic>? ?? [];
    if (monthlyStats.isEmpty) return const SizedBox();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度明细', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 2, child: Text('月份', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('交易', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('盈亏', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                  const Expanded(flex: 1, child: Text('胜率', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                ],
              ),
            ),
            ...monthlyStats.map((s) {
              final m = s as Map<String, dynamic>;
              final profit = (m['profit'] as num?)?.toDouble() ?? 0;
              final winRate = (m['winRate'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(m['month'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 1, child: Text('${m['trades'] ?? 0}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 1, child: Text(
                      _formatMoney(profit),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: profit >= 0 ? Colors.red : Colors.green),
                    )),
                    Expanded(flex: 1, child: Text(
                      '${winRate.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: winRate >= 50 ? Colors.red : Colors.green),
                    )),
                  ],
                ),
              );
            }),
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

  String _formatShortMoney(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}w';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
