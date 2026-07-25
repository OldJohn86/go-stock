import 'package:flutter/material.dart';

import '../models/stock_info.dart';
import '../widgets/price_change.dart';

/// 股票详情页（K 线等后续添加）
class StockDetailPage extends StatelessWidget {
  final StockRealTime stock;

  const StockDetailPage({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.stockName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.currentPrice.toStringAsFixed(2),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: stock.isUp ? Colors.red : Colors.green,
                      ),
                    ),
                    PriceChange(
                      change: stock.change,
                      changePercent: stock.changePercent,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(stock.stockCode,
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoRow(theme, '今开', stock.open.toStringAsFixed(2)),
          _infoRow(theme, '昨收', stock.preClose.toStringAsFixed(2)),
          _infoRow(theme, '最高', stock.high.toStringAsFixed(2)),
          _infoRow(theme, '最低', stock.low.toStringAsFixed(2)),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '更多功能开发中…\nK 线图、技术指标、AI 分析',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
