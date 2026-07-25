import 'package:flutter/material.dart';

import '../models/stock_info.dart';
import 'price_change.dart';

/// 股票信息卡片
class StockCard extends StatelessWidget {
  final StockRealTime stock;
  final VoidCallback? onTap;

  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          stock.stockName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          stock.stockCode,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              stock.currentPrice.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: stock.isUp ? Colors.red : Colors.green,
              ),
            ),
            PriceChange(
              change: stock.change,
              changePercent: stock.changePercent,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
