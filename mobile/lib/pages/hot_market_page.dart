import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/market_api.dart';
import 'stock_detail_page.dart';

/// 热门市场数据页（热门股票 + 热门事件 + 热门题材）
class HotMarketPage extends ConsumerStatefulWidget {
  const HotMarketPage({super.key});

  @override
  ConsumerState<HotMarketPage> createState() => _HotMarketPageState();
}

class _HotMarketPageState extends ConsumerState<HotMarketPage>
    with SingleTickerProviderStateMixin {
  final _api = MarketApi();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热门市场'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '热门股票'),
            Tab(text: '热门事件'),
            Tab(text: '热门题材'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HotStocksTab(api: _api),
          _HotEventsTab(api: _api),
          _HotTopicsTab(api: _api),
        ],
      ),
    );
  }
}

// ============ 热门股票 Tab ============
class _HotStocksTab extends ConsumerStatefulWidget {
  final MarketApi api;
  const _HotStocksTab({required this.api});

  @override
  ConsumerState<_HotStocksTab> createState() => _HotStocksTabState();
}

class _HotStocksTabState extends ConsumerState<_HotStocksTab> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getHotStocks(size: 50);
      if (mounted) setState(() => _list = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _list[index];
          final name = (item['name'] as String?) ?? '';
          final code = (item['code'] as String?) ?? '';
          final current = (item['current'] as num?)?.toDouble() ?? 0;
          final percent = (item['percent'] as num?)?.toDouble() ?? 0;

          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: index < 3 ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: code.isNotEmpty ? Text(code, style: TextStyle(fontSize: 12, color: Colors.grey[500])) : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  current.toStringAsFixed(2),
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: percent >= 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            onTap: () {
              if (code.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StockDetailPage.fromCode(code, name)),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ============ 热门事件 Tab ============
class _HotEventsTab extends ConsumerStatefulWidget {
  final MarketApi api;
  const _HotEventsTab({required this.api});

  @override
  ConsumerState<_HotEventsTab> createState() => _HotEventsTabState();
}

class _HotEventsTabState extends ConsumerState<_HotEventsTab> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getHotEvents(size: 30);
      if (mounted) setState(() => _list = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_list.isEmpty) {
      return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _list[index];
          final content = (item['content'] as String?) ?? '';
          final tag = (item['tag'] as String?) ?? '';
          final hot = (item['hot'] as num?)?.toInt() ?? 0;

          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: index < 3 ? Colors.red : Colors.grey[500],
                ),
              ),
            ),
            title: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Row(
              children: [
                if (tag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.orange)),
                  ),
                if (tag.isNotEmpty) const SizedBox(width: 8),
                Text('热度: $hot', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============ 热门题材 Tab ============
class _HotTopicsTab extends ConsumerStatefulWidget {
  final MarketApi api;
  const _HotTopicsTab({required this.api});

  @override
  ConsumerState<_HotTopicsTab> createState() => _HotTopicsTabState();
}

class _HotTopicsTabState extends ConsumerState<_HotTopicsTab> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getHotTopics(size: 30);
      if (mounted) setState(() => _list = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_list.isEmpty) {
      return Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey[500])));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _list[index];
          // Try common field names
          final name = (item['name'] as String?) ?? (item['topic_name'] as String?) ?? '';
          final hot = (item['hot'] as num?)?.toInt() ?? (item['hot_value'] as num?)?.toInt() ?? 0;
          final desc = (item['desc'] as String?) ?? (item['description'] as String?) ?? '';

          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: index < 3 ? Colors.red : Colors.grey[500],
                ),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: desc.isNotEmpty
                ? Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))
                : null,
            trailing: hot > 0 ? Text('热度: $hot', style: TextStyle(fontSize: 11, color: Colors.grey[500])) : null,
          );
        },
      ),
    );
  }
}
