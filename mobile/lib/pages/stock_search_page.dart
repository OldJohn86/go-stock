import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/stock_provider.dart';
import 'stock_detail_page.dart';

/// 全局股票搜索页
///
/// 全屏搜索，输入股票代码或名称自动过滤，支持关注/取消关注操作。
class StockSearchPage extends ConsumerStatefulWidget {
  const StockSearchPage({super.key});

  @override
  ConsumerState<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends ConsumerState<StockSearchPage> {
  final _searchController = TextEditingController();
  final StockApi _api = StockApi();
  Timer? _debounce;

  /// 全市场股票列表（全量缓存）
  List<StockRealTime> _allStocks = [];
  bool _loading = true;
  String? _error;

  /// 搜索过滤结果
  List<StockRealTime> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchAllStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// 获取全市场股票列表并缓存
  Future<void> _fetchAllStocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 使用缓存获取全部股票（pageSize 设为 10000 以获取几乎所有股票）
      final stocks = await _api.getStockListCached(
        page: 1,
        pageSize: 10000,
      );
      if (mounted) {
        setState(() {
          _allStocks = stocks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '数据加载失败，请检查网络后重试';
        });
      }
    }
  }

  /// 输入变化时触发防抖过滤
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isSearching = query.isNotEmpty;
        if (query.isEmpty) {
          _results = [];
        } else {
          final q = query.toUpperCase();
          _results = _allStocks.where((s) {
            return s.stockCode.toUpperCase().contains(q) ||
                s.stockName.toUpperCase().contains(q);
          }).toList();
        }
      });
    });
  }

  /// 切换关注状态
  Future<void> _toggleFollow(String stockCode) async {
    final followAsync = ref.read(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};
    if (followedCodes.contains(stockCode)) {
      await _api.unfollowStock(stockCode);
    } else {
      await _api.followStock(stockCode);
    }
    if (mounted) {
      ref.read(followListProvider.notifier).refresh();
    }
  }

  /// 跳转详情页
  void _openDetail(StockRealTime stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stock: stock),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final followAsync = ref.watch(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: '搜索股票名称或代码',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _results = [];
                        _isSearching = false;
                      });
                    },
                  )
                : null,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          ),
        ),
      ),
      body: _buildBody(followedCodes),
    );
  }

  Widget _buildBody(Set<String> followedCodes) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchAllStocks,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (!_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey[350],
            ),
            const SizedBox(height: 16),
            Text(
              '输入股票名称或代码开始搜索',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '未找到相关股票',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '请尝试其他搜索词',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final stock = _results[i];
        final isFollowed = followedCodes.contains(stock.stockCode);
        return _buildResultItem(stock, isFollowed);
      },
    );
  }

  Widget _buildResultItem(StockRealTime stock, bool isFollowed) {
    final theme = Theme.of(context);
    final isUp = stock.isUp;
    final priceColor = isUp ? Colors.red : Colors.green;

    // 取股票名称的第一个字符作为头像
    final initial =
        stock.stockName.isNotEmpty ? stock.stockName[0] : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(stock),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stock.stockCode,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Follow/unfollow star button
              IconButton(
                icon: Icon(
                  isFollowed ? Icons.star : Icons.star_border,
                  color: isFollowed ? Colors.amber : Colors.grey[400],
                  size: 26,
                ),
                tooltip: isFollowed ? '取消关注' : '关注',
                onPressed: () => _toggleFollow(stock.stockCode),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
