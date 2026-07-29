import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/group_provider.dart';
import '../providers/stock_provider.dart';
import '../widgets/index_bar.dart';
import 'group_manage_page.dart';
import 'hot_market_page.dart';
import 'long_tiger_page.dart';
import 'market_radar_page.dart';
import 'sector_ranking_page.dart';
import 'tdx_deep_data_page.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_page.dart';

/// 行情页 — 自选 / 全市场
class StockListPage extends ConsumerStatefulWidget {
  const StockListPage({super.key});

  @override
  ConsumerState<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends ConsumerState<StockListPage>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  // 全市场数据（MarketPage 独立管理，此处保留兼容旧代码）
  List<StockRealTime> _marketStocks = [];
  bool _marketLoading = false;
  String? _marketError;
  int _page = 1;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // 自动刷新
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;
  bool _isScrolling = false;
  bool _isAppVisible = true;

  // 分组弹窗相关

  // 编辑模式
  bool _isEditing = false;
  final Set<String> _selectedCodes = {};

  // 大盘指数引用（供外部自动刷新调用）
  final GlobalKey<IndexBarState> _indexBarKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 加载自选列表（由 provider 自动触发），同时加载市场列表
    _fetchMarketStocks();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppVisible = true;
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppVisible = false;
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _onAutoRefresh();
    });
    if (!_isAutoRefreshing) {
      setState(() => _isAutoRefreshing = true);
    }
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (_isAutoRefreshing) {
      setState(() => _isAutoRefreshing = false);
    }
  }

  Future<void> _onAutoRefresh() async {
    if (!_isAppVisible || _isScrolling || !mounted) return;
    // 刷新大盘指数
    _indexBarKey.currentState?.refresh();
    ref.read(followListProvider.notifier).refresh();
  }

  List<StockRealTime> get _displayedStocks {
    if (_searchQuery.isEmpty) return _marketStocks;
    final query = _searchQuery.toUpperCase();
    return _marketStocks.where((s) =>
      s.stockCode.toUpperCase().contains(query) ||
      s.stockName.toUpperCase().contains(query)
    ).toList();
  }

  Future<void> _fetchMarketStocks({
    bool loadMore = false,
    bool showLoading = true,
  }) async {
    if (!loadMore) {
      setState(() {
        _marketLoading = showLoading;
        if (showLoading) _marketError = null;
      });
    }
    try {
      final api = StockApi();
      final stocks = await api.getStockList(
        page: loadMore ? _page + 1 : 1,
        pageSize: 50,
        name: '',
      );
      if (mounted) {
        setState(() {
          if (loadMore) {
            _marketStocks.addAll(stocks);
            _page++;
          } else {
            _marketStocks = stocks;
            _page = 1;
          }
          _marketLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _marketLoading = false;
          if (!loadMore && showLoading) {
            _marketError = '数据加载失败，请检查网络后重试';
          }
        });
      }
    }
  }

  /// 切换关注状态（用于市场页搜索结果的星标按钮）
  Future<void> _toggleFollow(String stockCode) async {
    final api = StockApi();
    final followAsync = ref.read(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};
    if (followedCodes.contains(stockCode)) {
      await api.unfollowStock(stockCode);
    } else {
      await api.followStock(stockCode);
    }
    ref.read(followListProvider.notifier).refresh();
  }

  /// 从自选列表取消关注
  Future<void> _unfollowFromWatchlist(String stockCode) async {
    final api = StockApi();
    await api.unfollowStock(stockCode);
    ref.read(followListProvider.notifier).refresh();
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

  @override
  Widget build(BuildContext context) {
    final followAsync = ref.watch(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};

    return Scaffold(
      body: Column(
        children: [
          // 大盘指数栏
          IndexBar(key: _indexBarKey),
          // 子标签栏（自选/分组/市场 + 行情工具入口）
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _segmentedButton('自选', Icons.star, 0),
                  const SizedBox(width: 8),
                  _subTabDivider(),
                  _subTabButton('板块', Icons.grid_view, () => _push(const SectorRankingPage())),
                  _subTabButton('雷达', Icons.radar, () => _push(const MarketRadarPage())),
                  _subTabButton('热门', Icons.local_fire_department, () => _push(const HotMarketPage())),
                  _subTabButton('龙虎榜', Icons.trending_up, () => _push(const LongTigerPage())),
                  _subTabButton('TDX', Icons.data_exploration, () => _push(const TdxDeepDataPage())),
                  if (_isAutoRefreshing) ...[const SizedBox(width: 8), _buildAutoRefreshIndicator()],
                ],
              ),
            ),
          ),
          // Body content
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification &&
                    !_isScrolling) {
                  setState(() => _isScrolling = true);
                } else if (notification is ScrollEndNotification &&
                    _isScrolling) {
                  setState(() => _isScrolling = false);
                }
                return false;
              },
              child: _buildFollowTab(followAsync, followedCodes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRefreshIndicator() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '自动刷新中',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subTabDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.grey.withValues(alpha: 0.3),
    );
  }

  Widget _subTabButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _segmentedButton(
      String label, IconData icon, int index) {
    final selected = _tabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = index);
        // 切换到"自选"时自动刷新
        if (index == 0) {
          ref.read(followListProvider.notifier).refresh();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowTab(AsyncValue<List<StockRealTime>> followAsync, Set<String> followedCodes) {
    return Column(
      children: [
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(followListProvider.notifier).refresh(),
            child: followAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e, isFollow: true),
              data: (stocks) {
                if (stocks.isEmpty) {
                  return _buildEmpty(
                    icon: Icons.star_border,
                    title: '还没有关注任何股票',
                    subtitle: '切换到"市场"页浏览并关注喜欢的股票',
                    actionLabel: '去浏览市场',
                    action: () => setState(() => _tabIndex = 1),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4),
                        itemCount: stocks.length,
                        itemBuilder: (_, i) => RepaintBoundary(
                          child: _buildFollowItem(stocks[i]),
                        ),
                      ),
                    ),
                    // 编辑模式底部操作栏
                    if (_isEditing)
                      _buildEditActionBar(stocks, ref),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditActionBar(
      List<StockRealTime> stocks, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // 全选 / 取消全选
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedCodes.length == stocks.length) {
                  _selectedCodes.clear();
                } else {
                  _selectedCodes.addAll(stocks.map((s) => s.stockCode));
                }
              });
            },
            child: Text(
              _selectedCodes.length == stocks.length ? '取消全选' : '全选',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Spacer(),
          // 删除选中
          FilledButton.tonalIcon(
            onPressed: _selectedCodes.isEmpty
                ? null
                : () => _batchDeleteSelected(ref),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text('删除选中 (${_selectedCodes.length})'),
          ),
        ],
      ),
    );
  }

  /// 批量删除选中股票
  Future<void> _batchDeleteSelected(WidgetRef ref) async {
    final api = StockApi();
    bool allSuccess = true;
    for (final code in _selectedCodes) {
      try {
        await api.unfollowStock(code);
      } catch (_) {
        allSuccess = false;
      }
    }
    if (mounted) {
      ref.read(followListProvider.notifier).refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(allSuccess ? '已删除 ${_selectedCodes.length} 只股票' : '部分删除失败')),
      );
      setState(() {
        _selectedCodes.clear();
        _isEditing = false;
      });
    }
  }

  Widget _buildFollowItem(StockRealTime stock) {
    if (_isEditing) {
      final isSelected = _selectedCodes.contains(stock.stockCode);
      return StockCard(
        stock: stock,
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedCodes.remove(stock.stockCode);
            } else {
              _selectedCodes.add(stock.stockCode);
            }
          });
        },
        onLongPress: () => _showAddToGroupSheet(stock),
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isSelected ? Colors.amber : Colors.grey[400],
            size: 24,
          ),
        ),
        trailing: null,
      );
    }

    return Dismissible(
      key: ValueKey('follow_${stock.stockCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        return true;
      },
      onDismissed: (_) {
        _unfollowFromWatchlist(stock.stockCode);
      },
      child: StockCard(
        stock: stock,
        onTap: () => _openDetail(stock),
        onLongPress: () => _showAddToGroupSheet(stock),
        trailing: IconButton(
            icon: Icon(Icons.remove_circle_outline, color: Colors.red[300], size: 20),
            tooltip: '取消关注',
            onPressed: () => _unfollowFromWatchlist(stock.stockCode),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
    );
  }

  Widget _buildMarketTab(Set<String> followedCodes) {
    final displayed = _displayedStocks;

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: '搜索股票名称或代码',
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
            ),
            onSubmitted: (_) {},
          ),
        ),
        // 列表
        Expanded(
          child: _marketLoading && _marketStocks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _marketError != null && _marketStocks.isEmpty
                  ? _buildError(ref, _marketError!, isFollow: false)
                  : RefreshIndicator(
                      onRefresh: () => _fetchMarketStocks(),
                      child: displayed.isEmpty
                          ? _buildEmpty(
                              icon: Icons.search_off,
                              title: '未找到相关股票',
                              subtitle: '请尝试其他搜索词',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 4),
                              itemCount: displayed.length + 1,
                              itemBuilder: (_, i) {
                                if (i == displayed.length) {
                                  if (_searchQuery.isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return _marketLoading
                                      ? const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        )
                                      : RepaintBoundary(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Center(
                                              child: TextButton(
                                                onPressed: () =>
                                                    _fetchMarketStocks(
                                                        loadMore: true),
                                                child: const Text('加载更多'),
                                              ),
                                            ),
                                          ),
                                        );
                                }
                                final stock = displayed[i];
                                final isFollowed =
                                    followedCodes.contains(stock.stockCode);
                                return RepaintBoundary(
                                  child: StockCard(
                                    stock: stock,
                                    onTap: () => _openDetail(stock),
                                    onLongPress: () =>
                                        _showAddToGroupSheet(stock),
                                    trailing: IconButton(
                                        icon: Icon(
                                          isFollowed
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: isFollowed
                                              ? Colors.amber
                                              : Colors.grey[400],
                                          size: 22,
                                        ),
                                        tooltip: isFollowed ? '取消关注' : '关注',
                                        onPressed: () =>
                                            _toggleFollow(stock.stockCode),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildError(WidgetRef ref, Object error, {bool isFollow = false}) {
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isFollow
                ? () => ref.read(followListProvider.notifier).refresh()
                : () => _fetchMarketStocks(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          if (actionLabel != null && action != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.explore, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetail(StockRealTime stock) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stock: stock),
      ),
    );
  }
}
