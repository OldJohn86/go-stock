import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../api/api_client.dart';
import '../api/stock_api.dart';
import '../models/kline_data.dart';
import '../models/minute_data.dart';
import '../models/stock_info.dart';
import '../utils/cache_manager.dart';
import '../widgets/indicator_chart.dart';
import '../widgets/kline_chart.dart';
import '../widgets/minute_chart.dart';
import '../widgets/price_change.dart';

/// 股票详情页（含 K线 / 分时 / 详情）
class StockDetailPage extends StatefulWidget {
  final StockRealTime stock;

  const StockDetailPage({super.key, required this.stock});

  /// 从股票代码和名称快速导航（会异步拉取实时行情）
  factory StockDetailPage.fromCode(String code, String name) {
    return StockDetailPage(stock: StockRealTime.fromCode(code, name));
  }

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StockApi _api = StockApi();

  // 自选状态
  bool _isFollowed = false;
  bool _followChecking = true;

  // K线数据
  List<KLineData> _klineData = [];
  bool _klineLoading = false;
  String _klineType = '101'; // 101=日K
  String? _klineError;

  // 分时数据
  List<MinuteData> _minuteData = [];
  String _minuteDate = '';
  bool _minuteLoading = false;
  String? _minuteError;

  // 价格信息（更新用）
  late StockRealTime _stock;

  // 技术指标
  IndicatorType _indicatorType = IndicatorType.none;

  // F10 财务数据
  String _financeMarkdown = '';
  bool _financeLoading = false;
  bool _financeLoaded = false;
  String? _financeError;

  /// HK stock code detection (mirrors backend IsHKCodeForRoute logic)
  bool get _isHKStock {
    final code = _stock.stockCode.toUpperCase().trim();
    if (code.isEmpty) return false;
    // .HK suffix or HK prefix
    if (code.endsWith('.HK') || code.startsWith('HK')) return true;
    // Pure numeric and length <= 5 (A-shares are always 6 digits)
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return code.length <= 5;
    }
    return false;
  }

  /// Human-readable market label
  String get _marketLabel => _isHKStock ? '港股' : 'A股';

  final List<_KLineTypeOption> _klineTypes = [
    _KLineTypeOption('日K', '101'),
    _KLineTypeOption('周K', '102'),
    _KLineTypeOption('月K', '103'),
    _KLineTypeOption('5分', '5'),
    _KLineTypeOption('15分', '15'),
    _KLineTypeOption('30分', '30'),
    _KLineTypeOption('60分', '60'),
  ];

  @override
  void initState() {
    super.initState();
    _stock = widget.stock;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 检查自选状态
    _checkFollowStatus();
    // 如果是从代码快速进入，先拉实时行情
    if (_stock.currentPrice == 0) _fetchRealTimePrice();
    // 默认加载K线
    _fetchKLineData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0: // K线
          if (_klineData.isEmpty) _fetchKLineData();
          break;
        case 1: // 分时
          if (_minuteData.isEmpty) _fetchMinuteData();
          break;
        case 2: // 详情
          if (!_financeLoaded) _fetchF10Data();
          break;
      }
    }
  }

  Future<void> _fetchKLineData() async {
    setState(() {
      _klineLoading = true;
      _klineError = null;
    });
    try {
      final data = await _api.getKLineData(_stock.stockCode, type: _klineType);
      if (mounted) {
        setState(() {
          _klineData = data;
          _klineLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _klineLoading = false;
          _klineError =
              '加载K线数据失败: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}';
        });
      }
    }
  }

  Future<void> _fetchMinuteData() async {
    setState(() {
      _minuteLoading = true;
      _minuteError = null;
    });
    try {
      final result = await _api.getMinuteData(_stock.stockCode);
      if (mounted) {
        setState(() {
          _minuteData = result['data'] as List<MinuteData>;
          _minuteDate = result['date'] as String;
          _minuteLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _minuteLoading = false;
          _minuteError = '加载分时数据失败';
        });
      }
    }
  }

  // ---- 自选股操作 ----
  Future<void> _checkFollowStatus() async {
    try {
      final list = await _api.getFollowList();
      if (mounted) {
        setState(() {
          _isFollowed = list.any((s) => s.stockCode == _stock.stockCode);
          _followChecking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _followChecking = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowed) {
      final msg = await _api.unfollowStock(_stock.stockCode);
      if (mounted) {
        setState(() => _isFollowed = false);
        if (msg.contains('成功')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已取消关注')));
        }
      }
    } else {
      final msg = await _api.followStock(_stock.stockCode);
      if (mounted) {
        setState(() => _isFollowed = true);
        if (msg.contains('成功')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已添加自选')));
        }
      }
    }
  }

  Future<void> _fetchRealTimePrice() async {
    try {
      // 使用缓存获取实时行情（30秒 TTL）
      final realTime = await _api.getRealTimePriceCached(_stock.stockCode);
      if (realTime != null && mounted) {
        setState(() => _stock = realTime);
      }
    } catch (_) {}
  }

  Future<void> _fetchF10Data() async {
    if (_financeLoading || _financeLoaded) return;
    setState(() {
      _financeLoading = true;
      _financeError = null;
    });
    try {
      final endpoint =
          _isHKStock ? '/f10/hk-finance' : '/f10/latest-finance';
      // 缓存 F10 财务数据，TTL 1 小时（财务数据变化不频繁）
      final resp = await ApiClient().getCached(
        endpoint,
        params: {'stockCode': _stock.stockCode},
        maxAge: CacheManager.financeMaxAge,
      );
      if (mounted) {
        setState(() {
          _financeMarkdown = resp.isSuccess && resp.data != null
              ? (resp.data['markdown'] ?? '').toString()
              : '';
          _financeLoaded = true;
          _financeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _financeMarkdown = '获取财务数据失败: $e';
          _financeLoaded = true;
          _financeLoading = false;
          _financeError = '加载财务数据失败';
        });
      }
    }
  }

  void _onKLineTypeChanged(String type) {
    if (_klineType == type) return;
    setState(() {
      _klineType = type;
      _klineData = [];
      _klineError = null;
      _indicatorType = IndicatorType.none;
    });
    _fetchKLineData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stock.stockName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              switch (_tabController.index) {
                case 0:
                  _fetchKLineData();
                  break;
                case 1:
                  _fetchMinuteData();
                  break;
              }
            },
          ),
          if (!_followChecking)
            IconButton(
              icon: Icon(
                _isFollowed ? Icons.star : Icons.star_border,
                color: _isFollowed ? Colors.amber : null,
              ),
              tooltip: _isFollowed ? '取消关注' : '添加自选',
              onPressed: _toggleFollow,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stock.currentPrice.toStringAsFixed(2),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _stock.isUp ? Colors.red : Colors.green,
                      ),
                    ),
                    PriceChange(
                      change: _stock.change,
                      changePercent: _stock.changePercent,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _stock.stockCode,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _isHKStock
                            ? const Color(0xFF009B77)
                            : const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _marketLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // TabBar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'K线'),
                Tab(text: '分时'),
                Tab(text: '详情'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKLineTab(context),
                _buildMinuteTab(context),
                _buildDetailTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTab(String title, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _onRefreshCurrentTab,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefreshCurrentTab() async {
    switch (_tabController.index) {
      case 0:
        _klineError = null;
        _klineData = [];
        await _fetchKLineData();
        break;
      case 1:
        _minuteError = null;
        _minuteData = [];
        await _fetchMinuteData();
        break;
      case 2:
        _financeError = null;
        _financeLoaded = false;
        _financeMarkdown = '';
        // 手动刷新时清除 F10 缓存
        final f10Endpoint =
            _isHKStock ? '/f10/hk-finance' : '/f10/latest-finance';
        await ApiClient().clearCache(
          f10Endpoint,
          params: {'stockCode': _stock.stockCode},
        );
        await _fetchF10Data();
        break;
    }
  }

  Widget _buildKLineTab(BuildContext context) {
    return Column(
      children: [
        // 周期选择器
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: _klineTypes.map((opt) {
              final selected = _klineType == opt.type;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : null,
                    ),
                  ),
                  selected: selected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _onKLineTypeChanged(opt.type),
                ),
              );
            }).toList(),
          ),
        ),
        // 技术指标切换
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _indicatorChip('关闭', IndicatorType.none),
              const SizedBox(width: 6),
              _indicatorChip('MACD', IndicatorType.macd),
              const SizedBox(width: 6),
              _indicatorChip('KDJ', IndicatorType.kdj),
              const SizedBox(width: 6),
              _indicatorChip('RSI', IndicatorType.rsi),
            ],
          ),
        ),
        // K线图 + 指标子图
        Expanded(
          child: _klineLoading
              ? const Center(child: CircularProgressIndicator())
              : _klineError != null
              ? _buildErrorTab('K线数据加载失败', _klineError!)
              : _klineData.isEmpty
              ? const Center(child: Text('暂无K线数据'))
              : Column(
                  children: [
                    const SizedBox(height: 4),
                    const KLineLegend(),
                    Expanded(
                      child: KLineChart(
                        data: _klineData,
                        height: double.infinity,
                      ),
                    ),
                    if (_indicatorType != IndicatorType.none)
                      IndicatorChart(
                        data: _klineData,
                        type: _indicatorType,
                        height: 110,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _indicatorChip(String label, IndicatorType type) {
    final selected = _indicatorType == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: selected ? Colors.white : null),
      ),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _indicatorType = type),
    );
  }

  Widget _buildMinuteTab(BuildContext context) {
    return _minuteLoading
        ? const Center(child: CircularProgressIndicator())
        : _minuteError != null
        ? _buildErrorTab('分时数据加载失败', _minuteError!)
        : _minuteData.isEmpty
        ? const Center(child: Text('暂无分时数据'))
        : MinuteChart(
            data: _minuteData,
            date: _minuteDate,
            preClose: _stock.preClose,
            height: double.infinity,
          );
  }

  Widget _buildDetailTab(BuildContext context) {
    final theme = Theme.of(context);

    if (_financeError != null && _financeMarkdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _financeError!,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _financeError = null;
                  _financeLoaded = false;
                  _financeMarkdown = '';
                });
                _fetchF10Data();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _financeError = null;
          _financeLoaded = false;
          _financeMarkdown = '';
        });
        await _fetchF10Data();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '基本信息',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _isHKStock
                              ? const Color(0xFF009B77)
                              : const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _marketLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoRow(theme, '今开', _stock.open.toStringAsFixed(2)),
                  _infoRow(theme, '昨收', _stock.preClose.toStringAsFixed(2)),
                  _infoRow(theme, '最高', _stock.high.toStringAsFixed(2)),
                  _infoRow(theme, '最低', _stock.low.toStringAsFixed(2)),
                  _infoRow(theme, '日期', _stock.date),
                  _infoRow(theme, '时间', _stock.time),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_financeLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_financeMarkdown.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '财务数据 (F10)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MarkdownBody(
                      data: _financeMarkdown,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                        tableHead: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        tableBody: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                        ),
                        tableBorder: TableBorder.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
          Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _KLineTypeOption {
  final String label;
  final String type;
  const _KLineTypeOption(this.label, this.type);
}
