import 'package:flutter/material.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';

/// 大盘指数栏 — 横向滚动显示主要指数行情
class IndexBar extends StatefulWidget {
  const IndexBar({super.key});

  @override
  State<IndexBar> createState() => IndexBarState();
}

class IndexBarState extends State<IndexBar> {
  final StockApi _api = StockApi();
  List<StockRealTime> _indices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchIndices();
  }

  Future<void> _fetchIndices() async {
    try {
      final data = await _api.getIndexList();
      if (mounted) {
        setState(() {
          _indices = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 更新指数数据（供外部自动刷新调用）
  void refresh() {
    _fetchIndices();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 52,
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_indices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _indices.length,
        itemBuilder: (_, i) {
          final idx = _indices[i];
          return _buildIndexItem(idx, theme);
        },
      ),
    );
  }

  Widget _buildIndexItem(StockRealTime idx, ThemeData theme) {
    final isUp = idx.isUp;
    final color = isUp ? Colors.red : Colors.green;
    final name = _getName(idx.stockCode);
    final price = idx.currentPrice.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${isUp ? '+' : ''}${idx.changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getName(String code) {
    final normalized = code.toUpperCase();
    if (normalized.contains('000001')) return '上证';
    if (normalized.contains('399001')) return '深证';
    if (normalized.contains('399006')) return '创业板';
    if (normalized.contains('000688')) return '科创50';
    if (normalized.contains('000300')) return '沪深300';
    return code;
  }
}
