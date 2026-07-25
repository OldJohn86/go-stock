import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stock_info.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_page.dart';

/// 自选股列表页
class StockListPage extends ConsumerWidget {
  const StockListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stocksAsync = ref.watch(followListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(followListProvider.notifier).refresh(),
      child: stocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
        data: (stocks) {
          if (stocks.isEmpty) {
            return _buildEmpty(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: stocks.length,
            itemBuilder: (_, i) => StockCard(
              stock: stocks[i],
              onTap: () => _openDetail(context, stocks[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '获取数据失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => ref.read(followListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有关注任何股票',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '在搜索页或在 AI 分析中关注股票',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, StockRealTime stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stock: stock),
      ),
    );
  }
}
