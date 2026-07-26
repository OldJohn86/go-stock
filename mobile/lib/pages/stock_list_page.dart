import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/stock_api.dart';
import '../models/stock_info.dart';
import '../providers/group_provider.dart';
import '../providers/stock_provider.dart';
import '../widgets/stock_card.dart';
import 'group_manage_page.dart';
import 'group_stock_page.dart';
import 'stock_detail_page.dart';

/// 行情页 — 自选 / 全市场
class StockListPage extends ConsumerStatefulWidget {
  const StockListPage({super.key});

  @override
  ConsumerState<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends ConsumerState<StockListPage>
    with WidgetsBindingObserver {
  int _tabIndex = 0; // 0=自选, 1=分组, 2=市场

  // 全市场数据
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    if (_tabIndex == 0 || _tabIndex == 1) {
      ref.read(followListProvider.notifier).refresh();
    } else {
      await _fetchMarketStocks(showLoading: false);
    }
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

  @override
  Widget build(BuildContext context) {
    final followAsync = ref.watch(followListProvider);
    final followedCodes =
        followAsync.valueOrNull?.map((e) => e.stockCode).toSet() ?? {};

    return Scaffold(
      body: Column(
        children: [
          // Segmented buttons header (自选 / 分组 / 市场)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _segmentedButton('自选', Icons.star, 0),
                const SizedBox(width: 8),
                _segmentedButton('分组', Icons.folder, 1),
                const SizedBox(width: 8),
                _segmentedButton('市场', Icons.explore, 2),
                if (_isAutoRefreshing) _buildAutoRefreshIndicator(),
              ],
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
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildFollowTab(followAsync),
                  _buildGroupTab(),
                  _buildMarketTab(followedCodes),
                ],
              ),
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

  Widget _buildGroupTab() {
    final groups = ref.watch(groupListProvider);
    return Column(
      children: [
        // 分组管理入口
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '我的分组',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const GroupManagePage()),
                  );
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('管理'),
              ),
            ],
          ),
        ),
        // 分组网格
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined, size: 64,
                          color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '还没有创建分组',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const GroupManagePage()),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('创建分组'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(groupListProvider.notifier)
                      .load(),
                  child: GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final group = groups[i];
                      return Card(
                        elevation: 2,
                        shadowColor:
                            Theme.of(context).colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupStockPage(
                                  groupId: group.id,
                                  groupName: group.name,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.folder,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                                const SizedBox(height: 8),
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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

  Widget _buildFollowTab(AsyncValue<List<StockRealTime>> followAsync) {
    return RefreshIndicator(
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
              action: () => setState(() => _tabIndex = 2),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: stocks.length,
            itemBuilder: (_, i) => RepaintBoundary(
              child: _buildFollowItem(stocks[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowItem(StockRealTime stock) {
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
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
