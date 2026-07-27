import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../api/api_client.dart';
import '../api/stock_api.dart';
import '../api/trading_api.dart';
import '../models/kline_data.dart';
import '../models/minute_data.dart';
import '../models/stock_info.dart';
import '../utils/cache_manager.dart';
import '../widgets/indicator_chart.dart';
import '../widgets/kline_chart.dart';
import '../widgets/minute_chart.dart';
import '../widgets/price_change.dart';
import 'alert_setting_page.dart';
import 'kline_fullscreen_page.dart';
import 'sector_ranking_page.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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

  // 自动刷新
  Timer? _autoRefreshTimer;
  bool _isAppVisible = true;

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
    WidgetsBinding.instance.addObserver(this);
    _stock = widget.stock;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 检查自选状态
    _checkFollowStatus();
    // 如果是从代码快速进入，先拉实时行情
    if (_stock.currentPrice == 0) _fetchRealTimePrice();
    // 默认加载K线
    _fetchKLineData();
    // 启动自动刷新
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _onAutoRefresh();
    });
  }

  Future<void> _onAutoRefresh() async {
    if (!_isAppVisible || !mounted) return;
    final tab = _tabController.index;
    // 只在K线(0)和分时(1)标签下自动刷新
    if (tab > 1) return;

    // 刷新实时价格
    await _fetchRealTimePrice();

    // 根据当前标签刷新数据
    if (tab == 0 && _klineData.isNotEmpty) {
      await _fetchKLineData();
    } else if (tab == 1 && _minuteData.isNotEmpty) {
      await _fetchMinuteData();
    }
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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

  /// 快速添加交易记录（显示简单对话框）
  Future<void> _quickAddRecord(BuildContext context, String direction) async {
    final priceCtrl = TextEditingController(text: _stock.currentPrice > 0 ? _stock.currentPrice.toStringAsFixed(2) : '');
    final volumeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${direction == "买入" ? "买入" : "卖出"} ${_stock.stockName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: '价格',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return '请输入有效价格';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: volumeCtrl,
                decoration: const InputDecoration(
                  labelText: '数量（股）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final val = int.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return '请输入有效数量';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          }, child: const Text('保存')),
        ],
      ),
    );

    if (saved == true && mounted) {
      final ok = await TradingApi().saveRecord(
        stockCode: _stock.stockCode,
        stockName: _stock.stockName,
        direction: direction,
        price: double.parse(priceCtrl.text.trim()),
        volume: int.parse(volumeCtrl.text.trim()),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '交易记录已保存' : '保存失败，请重试')),
        );
      }
    }
    priceCtrl.dispose();
    volumeCtrl.dispose();
  }

  /// 显示 AI 股票分析
  Future<void> _showAIStockAnalysis(BuildContext context) async {
    final api = ApiClient();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Dialog content - will be updated
        return _AIStockAnalysisDialog(
          stockName: _stock.stockName,
          stockCode: _stock.stockCode,
          api: api,
        );
      },
    );
  }

  /// 显示分组选择对话框
  Future<void> _showGroupSelection(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final api = StockApi();
    final groups = await api.getGroupList();
    if (!mounted) return;

    if (groups.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('暂无分组，请先在分组管理中创建')),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(g['name'] as String? ?? ''),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await api.addStockToGroup(
                    groupId: g['id'] as int? ?? g['ID'] as int? ?? 0,
                    stockCode: _stock.stockCode,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '已加入分组' : '加入失败')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
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
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.fullscreen, size: 20),
                tooltip: '全屏',
                onPressed: _klineData.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KLineFullscreenPage(
                              data: _klineData,
                              stockName: _stock.stockName,
                              stockCode: _stock.stockCode,
                            ),
                          ),
                        );
                      },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
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
                  // 成交量/成交额
                  if (_stock.volume > 0) _infoRow(theme, '成交量', formatVolume(_stock.volume)),
                  if (_stock.amount > 0) _infoRow(theme, '成交额', formatAmount(_stock.amount)),
                ],
              ),
            ),
          ),
          // 技术指标摘要卡（新增）
          if (_klineData.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('技术指标', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (_klineType == '101')
                          Text('日K', style: TextStyle(fontSize: 11, color: theme.disabledColor))
                        else
                          Text(_klineTypes.firstWhere((t) => t.type == _klineType, orElse: () => _klineTypes[0]).label,
                              style: TextStyle(fontSize: 11, color: theme.disabledColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildMALines(theme),
                    const SizedBox(height: 8),
                    _buildMACDState(theme),
                  ],
                ),
              ),
            ),
          // 资金流向卡片
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('资金流向', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.grid_view, size: 14),
                        label: const Text('板块行情', style: TextStyle(fontSize: 12)),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SectorRankingPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 成交量可视化
                  if (_stock.volume > 0) ...[
                    _fundFlowRow(theme, '成交量', formatVolume(_stock.volume),
                        _stock.volume.toDouble(), 1.0),
                    const SizedBox(height: 8),
                  ],
                  if (_stock.amount > 0)
                    _fundFlowRow(theme, '成交额', formatAmount(_stock.amount),
                        _stock.amount, 1.0),
                  const SizedBox(height: 8),
                  // 买卖盘比例（使用买卖五档数据）
                  if (_stock.buyLevels.isNotEmpty || _stock.sellLevels.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildBuySellBar(theme),
                  ],
                  // 换手率估算（基于基础信息）
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('说明：成交量和成交额反映资金活跃度',
                          style: TextStyle(fontSize: 11, color: theme.disabledColor)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 快捷操作
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Row 1: 记录交易
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _quickAddRecord(context, '买入'),
                          icon: const Icon(Icons.shopping_cart, size: 16),
                          label: const Text('记录买入'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _quickAddRecord(context, '卖出'),
                          icon: const Icon(Icons.monetization_on, size: 16),
                          label: const Text('记录卖出'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 2: AI 分析 + 加入分组
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAIStockAnalysis(context),
                          icon: const Icon(Icons.psychology, size: 16),
                          label: const Text('AI 分析'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showGroupSelection(context),
                          icon: const Icon(Icons.folder, size: 16),
                          label: const Text('加入分组'),
                        ),
                      ),
                    ],
                  ),
                  // Row 3: 预警设置
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlertSettingPage()),
                          ),
                          icon: const Icon(Icons.notifications_active, size: 16),
                          label: const Text('预警设置'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 买卖五档
          if (_stock.buyLevels.isNotEmpty || _stock.sellLevels.isNotEmpty)
            _buildOrderBookCard(theme),
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

  /// 构建均线摘要行
  List<Widget> _buildMALines(ThemeData theme) {
    if (_klineData.isEmpty) return [];
    final currentPrice = _klineData.last.close;
    final maMap = _klineData.last.ma ?? {};

    if (maMap.isEmpty) return [];

    return maMap.entries.map((entry) {
      final maValue = entry.value;
      final isAbove = currentPrice >= maValue;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                entry.key,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              maValue.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(
              isAbove ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isAbove ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              '${isAbove ? '+' : '-'}${((currentPrice - maValue) / maValue * 100).abs().toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 11, color: isAbove ? Colors.red : Colors.green),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// 构建 MACD 状态指示
  Widget _buildMACDState(ThemeData theme) {
    if (_klineData.length < 2) return const SizedBox.shrink();
    // 简单判断：EMA12 > EMA26 ≈ 价格短期均线在长期均线之上（简化为当前价与过去均值关系）
    final maShort = _computeMA(5);
    final maLong = _computeMA(20);
    final isGolden = maShort > maLong && maShort > 0 && maLong > 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (isGolden ? Colors.red : Colors.green).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isGolden ? Colors.red : Colors.green).withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            isGolden ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: isGolden ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isGolden
                  ? '短期均线(${maShort.toStringAsFixed(2)}) > 长期均线(${maLong.toStringAsFixed(2)})，多头趋势'
                  : '长期均线(${maLong.toStringAsFixed(2)}) > 短期均线(${maShort.toStringAsFixed(2)})，空头趋势',
              style: TextStyle(fontSize: 11, color: isGolden ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  /// 计算简单移动平均
  double _computeMA(int period) {
    if (_klineData.length < period) return 0;
    double sum = 0;
    for (int i = _klineData.length - period; i < _klineData.length; i++) {
      sum += _klineData[i].close;
    }
    return sum / period;
  }

  Widget _buildOrderBookCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('买卖五档', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 卖五~卖一
            ...List.generate(_stock.sellLevels.length, (i) {
              final level = _stock.sellLevels[_stock.sellLevels.length - 1 - i];
              return _orderBookRow(
                theme,
                '卖${_stock.sellLevels.length - i}',
                level.price,
                level.volume,
                isBuy: false,
              );
            }),
            // 当前价
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text( _stock.currentPrice > 0
                      ? _stock.currentPrice.toStringAsFixed(2)
                      : '-',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _stock.isUp ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    '${_stock.currentPrice > 0 ? (_stock.isUp ? '+' : '') : ''}${_stock.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: _stock.isUp ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            // 买一~买五
            ...List.generate(_stock.buyLevels.length, (i) {
              final level = _stock.buyLevels[i];
              return _orderBookRow(
                theme,
                '买${i + 1}',
                level.price,
                level.volume,
                isBuy: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _orderBookRow(ThemeData theme, String label, double price, double volume, {required bool isBuy}) {
    final color = isBuy ? Colors.red : Colors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label, style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.7))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(price.toStringAsFixed(2), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(
            '${volume.toStringAsFixed(0)}手',
            style: TextStyle(fontSize: 13, color: theme.disabledColor),
          ),
        ],
      ),
    );
  }

  Widget _fundFlowRow(ThemeData theme, String label, String value, double amount, double maxAmount) {
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }

  Widget _buildBuySellBar(ThemeData theme) {
    final totalBuyVol = _stock.buyLevels.fold<double>(0, (sum, l) => sum + l.volume);
    final totalSellVol = _stock.sellLevels.fold<double>(0, (sum, l) => sum + l.volume);
    final total = totalBuyVol + totalSellVol;
    if (total <= 0) return const SizedBox();

    final buyRatio = totalBuyVol / total;
    final sellRatio = totalSellVol / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('买卖盘压力', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(width: 8),
            Text(
              '买 ${(buyRatio * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Text(
              '卖 ${(sellRatio * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (buyRatio * 100).round(),
                child: Container(height: 8, color: Colors.red.withValues(alpha: 0.6)),
              ),
              Expanded(
                flex: (sellRatio * 100).round(),
                child: Container(height: 8, color: Colors.green.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('买方 ${_formatVolume(totalBuyVol)}手', style: TextStyle(fontSize: 11, color: Colors.red.withValues(alpha: 0.7))),
            Text('卖方 ${_formatVolume(totalSellVol)}手', style: TextStyle(fontSize: 11, color: Colors.green.withValues(alpha: 0.7))),
          ],
        ),
      ],
    );
  }

  String _formatVolume(double vol) {
    if (vol >= 10000) {
      return '${(vol / 10000).toStringAsFixed(1)}万';
    }
    return vol.toStringAsFixed(0);
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

/// AI 股票分析对话框 — 异步调用并显示结果
class _AIStockAnalysisDialog extends StatefulWidget {
  final String stockName;
  final String stockCode;
  final ApiClient api;

  const _AIStockAnalysisDialog({
    required this.stockName,
    required this.stockCode,
    required this.api,
  });

  @override
  State<_AIStockAnalysisDialog> createState() => _AIStockAnalysisDialogState();
}

class _AIStockAnalysisDialogState extends State<_AIStockAnalysisDialog> {
  String _result = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    final prompt =
        '请分析 ${widget.stockName}(${widget.stockCode}) 的走势。从技术面（K线形态、均线、MACD、KDJ等指标）和基本面（财务数据、行业地位等）两个维度进行分析，给出操作建议。';
    try {
      final resp = await widget.api.post('/agent/chat', data: {
        'question': prompt,
        'aiConfigId': 1,
        'thinkingMode': 'false',
        'agentMode': 'react',
        'memoryMode': 'false',
      });
      if (mounted) {
        setState(() {
          if (resp.isSuccess && resp.data != null) {
            final data = resp.data as Map<String, dynamic>?;
            _result = data?['content'] as String? ?? '暂无分析结果';
          } else {
            _error = resp.message;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.stockName} AI 分析'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('分析失败', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(fontSize: 12)),
                ],
              )
            : SingleChildScrollView(
                child: SelectableText(_result),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
