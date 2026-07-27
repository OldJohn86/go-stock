import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/group_provider.dart';
import '../providers/stock_provider.dart';
import 'stock_detail_page.dart';

/// 全局股票搜索页
///
/// 优化：
/// - 服务端搜索优先（实时价格数据），本地缓存的股票列表作为代码搜索的后备
/// - 搜索历史记录
/// - 长按结果可添加到分组
class StockSearchPage extends ConsumerStatefulWidget {
  const StockSearchPage({super.key});

  @override
  ConsumerState<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends ConsumerState<StockSearchPage> {
  final _searchController = TextEditingController();
  final StockApi _api = StockApi();
  Timer? _debounce;

  /// 全市场股票列表（仅用于代码/名称搜索的后备匹配，懒加载）
  Map<String, StockRealTime> _allStocksMap = {};
  bool _localCacheLoaded = false;

  /// 服务端搜索结果
  List<StockRealTime> _results = [];
  bool _isLoading = false;
  String? _error;

  /// 搜索历史
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ==================== 搜索历史 ====================

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('search_history') ?? [];
    if (mounted) {
      setState(() => _recentSearches = raw);
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    await prefs.setStringList('search_history', _recentSearches);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (mounted) {
      setState(() => _recentSearches = []);
    }
  }

  // ==================== 股票搜索 ====================

  /// 懒加载本地股票代码名称索引（用于代码搜索的后备）
  Future<void> _ensureLocalCache() async {
    if (_localCacheLoaded) return;
    try {
      final stocks = await _api.getStockListCached(page: 1, pageSize: 10000);
      _allStocksMap = {for (final s in stocks) s.stockCode: s};
      _localCacheLoaded = true;
    } catch (_) {
      // 忽略，后备失败不影响主流程
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _doSearch(query);
    });
  }

  /// 执行搜索：服务端搜索 + 本地后备匹配
  Future<void> _doSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 1. 先尝试服务端搜索（按名称，返回实时价格数据）
    List<StockRealTime> serverResults = [];
    try {
      serverResults = await _api.getStockList(
        page: 1,
        pageSize: 50,
        name: query,
      );
    } catch (_) {
      // 服务端失败，继续用本地后备
    }

    // 2. 如果服务端结果太少，补充本地缓存匹配（按代码或名称）
    if (serverResults.length < 5) {
      await _ensureLocalCache();
      if (_allStocksMap.isNotEmpty) {
        final q = query.toUpperCase();
        final localMatches = _allStocksMap.values
            .where((s) =>
                s.stockCode.toUpperCase().contains(q) ||
                s.stockName.toUpperCase().contains(q))
            .toList();

        // 去重合并：服务端结果优先（含实时价格）
        final serverCodes = serverResults.map((s) => s.stockCode).toSet();
        for (final s in localMatches) {
          if (!serverCodes.contains(s.stockCode)) {
            serverResults.add(s);
          }
        }
      }
    }

    // 3. 保存搜索历史
    if (serverResults.isNotEmpty || query.isNotEmpty) {
      _saveSearchQuery(query);
    }

    if (mounted) {
      setState(() {
        _results = serverResults.take(50).toList();
        _isLoading = false;
        if (serverResults.isEmpty) {
          _error = '未找到相关股票';
        }
      });
    }
  }

  // ==================== 交互 ====================

  void _onHistoryTap(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _doSearch(query);
  }

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

  void _openDetail(StockRealTime stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stock: stock),
      ),
    );
  }

  /// 显示"添加到分组"底部弹窗
  void _showAddToGroupSheet(StockRealTime stock) {
    final groups = ref.read(groupListProvider);
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在"分组"页面创建分组')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '将 ${stock.stockName} (${stock.stockCode}) 添加到分组',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 16),
              ...groups.map((g) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(g.name),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final ok = await ref
                          .read(groupListProvider.notifier)
                          .addStockToGroup(
                            groupId: g.id,
                            stockCode: stock.stockCode,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? '已添加到「${g.name}」' : '添加失败',
                            ),
                          ),
                        );
                      }
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  // ==================== UI 构建 ====================

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
                        _isLoading = false;
                        _error = null;
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
      body: _buildBody(theme, followedCodes),
    );
  }

  Widget _buildBody(ThemeData theme, Set<String> followedCodes) {
    // 输入为空 → 显示搜索历史
    if (_searchController.text.isEmpty) {
      return _buildSearchHistory(theme);
    }

    // 加载中
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误 / 无结果
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '请尝试其他搜索词',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // 搜索结果列表
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final stock = _results[i];
        final isFollowed = followedCodes.contains(stock.stockCode);
        return _buildResultItem(stock, isFollowed, theme);
      },
    );
  }

  /// 搜索历史区域
  Widget _buildSearchHistory(ThemeData theme) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[350]),
            const SizedBox(height: 16),
            Text(
              '输入股票名称或代码开始搜索',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: const Text('清空', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (_, i) {
              final q = _recentSearches[i];
              return ListTile(
                leading: Icon(
                  Icons.history,
                  size: 20,
                  color: Colors.grey[500],
                ),
                title: Text(q, style: const TextStyle(fontSize: 14)),
                trailing: Icon(
                  Icons.arrow_upward,
                  size: 16,
                  color: Colors.grey[400],
                ),
                onTap: () => _onHistoryTap(q),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
      StockRealTime stock, bool isFollowed, ThemeData theme) {
    final isUp = stock.isUp;
    final priceColor = isUp ? Colors.red : Colors.green;

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
        onLongPress: () => _showAddToGroupSheet(stock),
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
