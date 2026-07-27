import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/trading_record.dart';

/// 交易统计图表组件
class TradingStatsCharts extends StatelessWidget {
  final TradingRecordStatistics stats;
  final List<TradingRecordItem> records;

  const TradingStatsCharts({
    super.key,
    required this.stats,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 盈亏概览条形图
        _buildProfitOverview(theme),
        const SizedBox(height: 16),
        // 买入卖出比例图
        _buildBuySellRatio(theme),
        const SizedBox(height: 16),
        // 近期盈亏走势
        _buildRecentProfitTrend(theme),
      ],
    );
  }

  Widget _buildProfitOverview(ThemeData theme) {
    final totalBuy = stats.totalBuyAmount;
    final totalSell = stats.totalSellAmount;
    final profit = stats.totalProfit;
    final maxVal = [totalBuy, totalSell, totalBuy - totalSell].fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxVal > 0 ? maxVal * 1.2 : 1000.0;

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
            Text('盈亏概览', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: scale,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label;
                        switch (groupIndex) {
                          case 0:
                            label = '买入总额';
                            break;
                          case 1:
                            label = '卖出总额';
                            break;
                          case 2:
                            label = '总盈亏';
                            break;
                          default:
                            label = '';
                        }
                        return BarTooltipItem(
                          '$label\n¥${rod.toY.toStringAsFixed(0)}',
                          TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('金额 (元)', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            _formatShort(value.toInt()),
                            style: TextStyle(fontSize: 10, color: theme.disabledColor),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = ['买入总额', '卖出总额', '总盈亏'];
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              labels[index],
                              style: TextStyle(fontSize: 10, color: theme.disabledColor),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: scale / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.disabledColor.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: [
                    _makeBarGroup(0, totalBuy, Colors.red.withValues(alpha: 0.7)),
                    _makeBarGroup(1, totalSell, Colors.green.withValues(alpha: 0.7)),
                    _makeBarGroup(2, profit.abs(), profit >= 0 ? Colors.red : Colors.green),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 24,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildBuySellRatio(ThemeData theme) {
    final totalBuy = stats.totalBuyAmount;
    final totalSell = stats.totalSellAmount;
    final total = totalBuy + totalSell;
    if (total <= 0) return const SizedBox();

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
            Text('买入/卖出比例', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            value: totalBuy,
                            color: Colors.red.withValues(alpha: 0.7),
                            radius: 35,
                            title: '${(totalBuy / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          PieChartSectionData(
                            value: totalSell,
                            color: Colors.green.withValues(alpha: 0.7),
                            radius: 35,
                            title: '${(totalSell / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem(theme, '买入', _formatMoney(totalBuy), Colors.red),
                      const SizedBox(height: 8),
                      _legendItem(theme, '卖出', _formatMoney(totalSell), Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(ThemeData theme, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: theme.disabledColor, fontSize: 13)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  Widget _buildRecentProfitTrend(ThemeData theme) {
    if (records.isEmpty) return const SizedBox();

    // 提取最近10条卖出记录按时间排序计算收益走势
    final sellRecords = records.where((r) => r.direction == '卖出').take(10).toList();
    if (sellRecords.isEmpty) return const SizedBox();

    // 对数据进行分组计算（按日期）
    final Map<String, double> dailyProfit = {};
    for (final r in sellRecords) {
      final date = r.tradingTime.length >= 10 ? r.tradingTime.substring(0, 10) : r.tradingTime;
      dailyProfit[date] = (dailyProfit[date] ?? 0) + r.profitAmount;
    }

    final dates = dailyProfit.keys.toList();
    if (dates.isEmpty) return const SizedBox();

    final values = dates.map((d) => dailyProfit[d]!).toList();
    final maxVal = values.fold<double>(0, (a, b) => a > b ? a : b);
    final minVal = values.fold<double>(0, (a, b) => a < b ? a : b);
    final range = (maxVal - minVal) > 0 ? maxVal - minVal : 1000.0;

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
            Text('近期卖出盈亏', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal * 1.2 : range,
                  minY: minVal < 0 ? minVal * 1.2 : 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final date = groupIndex < dates.length ? dates[groupIndex] : '';
                        return BarTooltipItem(
                          '$date\n¥${rod.toY.toStringAsFixed(2)}',
                          TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox();
                          return Text(
                            _formatShort(value.toInt()),
                            style: TextStyle(fontSize: 9, color: theme.disabledColor),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dates.length) return const SizedBox();
                          final date = dates[index];
                          final short = date.length >= 5 ? date.substring(5) : date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(short, style: TextStyle(fontSize: 9, color: theme.disabledColor)),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.disabledColor.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: List.generate(dates.length, (i) {
                    final v = values[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: v,
                          color: v >= 0 ? Colors.red.withValues(alpha: 0.7) : Colors.green.withValues(alpha: 0.7),
                          width: 16,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(v >= 0 ? 3 : 0), bottom: Radius.circular(v < 0 ? 3 : 0)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShort(int value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}w';
    }
    return value.toString();
  }

  String _formatMoney(double value) {
    if (value.abs() >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(2)}万';
    }
    return '¥${value.toStringAsFixed(2)}';
  }
}
