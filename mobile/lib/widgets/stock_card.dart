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
    final isUp = stock.isUp;
    final priceColor = isUp ? Colors.red : Colors.green;

    // 取股票名称的第一个字符作为头像
    final initial = stock.stockName.isNotEmpty ? stock.stockName[0] : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar with stock initial
              CircleAvatar(
                radius: 22,
                backgroundColor: priceColor.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: priceColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.stockName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stock.stockCode,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Price + change
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stock.currentPrice.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: priceColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  PriceChange(
                    change: stock.change,
                    changePercent: stock.changePercent,
                    style: TextStyle(fontSize: 12, color: priceColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
