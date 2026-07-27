import 'package:flutter/material.dart';

import '../api/stock_api.dart';
import 'stock_detail_page.dart';

/// 技术指标筛选器 — 支持 MACD 金叉、KDJ 金叉、K线形态等 30+ 条件
class StockScreenerPage extends StatefulWidget {
  const StockScreenerPage({super.key});

  @override
  State<StockScreenerPage> createState() => _StockScreenerPageState();
}

class _StockScreenerPageState extends State<StockScreenerPage> {
  final _api = StockApi();
  final _keywordCtrl = TextEditingController();

  // 筛选状态
  bool _macdGoldenFork = false;
  bool _kdjGoldenFork = false;
  bool _longAvgArray = false; // 均线多头排列
  bool _shortAvgArray = false; // 均线空头排列
  bool _breakUpMa5Days = false; // 向上突破5日均线
  bool _breakThrough = false; // 放量突破
  bool _oneDayangLine = false;
  bool _twoDayangLines = false;
  bool _powerFulgun = false; // 强势多方炮
  bool _riseSun = false; // 旭日东升
  bool _firstDawn = false; // 曙光初现
  bool _morningStar = false;
  bool _shootingStar = false;
  bool _eveningStar = false;
  bool _bearishEngulfing = false; // 穿头破脚
  bool _blackCloudTops = false; // 乌云盖顶
  bool _pregnant = false; // 身怀六甲
  bool _reversingHammer = false; // 倒转锤头
  bool _restoreJustice = false; // 拨云见日
  bool _narrowFinish = false; // 窄幅整理
  bool _upperLargeVolume = false; // 连涨放量
  bool _downNarrowVolume = false; // 下跌无量
  bool _upsideVolume = false; // 放量上攻
  bool _heavenRule = false; // 天量法则
  bool _lowFundsInflow = false; // 低位资金净流入
  bool _highFundsOutflow = false; // 高位资金净流出
  bool _down7Days = false; // 七连阴
  bool _upper8Days = false; // 八连阳
  bool _upper9Days = false; // 九连阳
  bool _upper4Days = false; // 四串阳

  // 排序
  String _sortField = 'CHANGE_RATE';
  bool _sortAsc = false;

  // 结果
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  static const _filterGroups = [
    _FilterGroup('技术指标', [
      _FilterDef('macdGoldenFork', 'MACD金叉', Icons.show_chart),
      _FilterDef('kdjGoldenFork', 'KDJ金叉', Icons.multiline_chart),
      _FilterDef('longAvgArray', '均线多头排列', Icons.trending_up),
      _FilterDef('shortAvgArray', '均线空头排列', Icons.trending_down),
      _FilterDef('breakUpMa5Days', '突破5日均线', Icons.arrow_upward),
    ]),
    _FilterGroup('K线形态', [
      _FilterDef('breakThrough', '放量突破', Icons.bolt),
      _FilterDef('oneDayangLine', '一根大阳线', Icons.straighten),
      _FilterDef('twoDayangLines', '两根大阳线', Icons.straighten),
      _FilterDef('powerFulgun', '强势多方炮', Icons.local_fire_department),
      _FilterDef('riseSun', '旭日东升', Icons.wb_sunny),
      _FilterDef('firstDawn', '曙光初现', Icons.wb_twilight),
      _FilterDef('morningStar', '早晨之星', Icons.brightness_5),
      _FilterDef('shootingStar', '射击之星', Icons.arrow_drop_down),
      _FilterDef('eveningStar', '黄昏之星', Icons.brightness_3),
      _FilterDef('bearishEngulfing', '穿头破脚', Icons.swap_horiz),
      _FilterDef('blackCloudTops', '乌云盖顶', Icons.cloud),
      _FilterDef('pregnant', '身怀六甲', Icons.circle),
      _FilterDef('reversingHammer', '倒转锤头', Icons.gavel),
      _FilterDef('restoreJustice', '拨云见日', Icons.wb_cloudy),
      _FilterDef('narrowFinish', '窄幅整理', Icons.horizontal_rule),
    ]),
    _FilterGroup('量价关系', [
      _FilterDef('upperLargeVolume', '连涨放量', Icons.trending_up),
      _FilterDef('downNarrowVolume', '下跌无量', Icons.trending_down),
      _FilterDef('upsideVolume', '放量上攻', Icons.rocket_launch),
      _FilterDef('heavenRule', '天量法则', Icons.thunderstorm),
    ]),
    _FilterGroup('资金流向', [
      _FilterDef('lowFundsInflow', '低位资金净流入', Icons.payments),
      _FilterDef('highFundsOutflow', '高位资金净流出', Icons.money_off),
    ]),
    _FilterGroup('连涨连跌', [
      _FilterDef('upper8Days', '八连阳', Icons.sunny),
      _FilterDef('upper9Days', '九连阳', Icons.sunny),
      _FilterDef('upper4Days', '四串阳', Icons.sunny),
      _FilterDef('down7Days', '七连阴', Icons.cloudy_snowing),
    ]),
  ];

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Map<String, bool> get _queryParams {
    return {
      'macdGoldenFork': _macdGoldenFork,
      'kdjGoldenFork': _kdjGoldenFork,
      'longAvgArray': _longAvgArray,
      'shortAvgArray': _shortAvgArray,
      'breakUpMa5Days': _breakUpMa5Days,
      'breakThrough': _breakThrough,
      'oneDayangLine': _oneDayangLine,
      'twoDayangLines': _twoDayangLines,
      'powerFulgun': _powerFulgun,
      'riseSun': _riseSun,
      'firstDawn': _firstDawn,
      'morningStar': _morningStar,
      'shootingStar': _shootingStar,
      'eveningStar': _eveningStar,
      'bearishEngulfing': _bearishEngulfing,
      'blackCloudTops': _blackCloudTops,
      'pregnant': _pregnant,
      'reversingHammer': _reversingHammer,
      'restoreJustice': _restoreJustice,
      'narrowFinish': _narrowFinish,
      'upperLargeVolume': _upperLargeVolume,
      'downNarrowVolume': _downNarrowVolume,
      'upsideVolume': _upsideVolume,
      'heavenRule': _heavenRule,
      'lowFundsInflow': _lowFundsInflow,
      'highFundsOutflow': _highFundsOutflow,
      'upper8Days': _upper8Days,
      'upper9Days': _upper9Days,
      'upper4Days': _upper4Days,
      'down7Days': _down7Days,
    };
  }

  Future<void> _search() async {
    setState(() => _loading = true);

    final enabled = _queryParams.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final result = await _api.getScreenerResults(
      keyword: _keywordCtrl.text.trim(),
      filters: enabled,
    );

    if (mounted) {
      setState(() {
        _results = result;
        _loading = false;
        _searched = true;
      });
    }
  }

  int get _activeFilterCount =>
      _queryParams.values.where((v) => v).length;

  void _clearAll() {
    setState(() {
      for (final key in _queryParams.keys) {
        _setFilter(key, false);
      }
      _results = [];
      _searched = false;
    });
  }

  void _setFilter(String key, bool value) {
    switch (key) {
      case 'macdGoldenFork':
        _macdGoldenFork = value;
        break;
      case 'kdjGoldenFork':
        _kdjGoldenFork = value;
        break;
      case 'longAvgArray':
        _longAvgArray = value;
        break;
      case 'shortAvgArray':
        _shortAvgArray = value;
        break;
      case 'breakUpMa5Days':
        _breakUpMa5Days = value;
        break;
      case 'breakThrough':
        _breakThrough = value;
        break;
      case 'oneDayangLine':
        _oneDayangLine = value;
        break;
      case 'twoDayangLines':
        _twoDayangLines = value;
        break;
      case 'powerFulgun':
        _powerFulgun = value;
        break;
      case 'riseSun':
        _riseSun = value;
        break;
      case 'firstDawn':
        _firstDawn = value;
        break;
      case 'morningStar':
        _morningStar = value;
        break;
      case 'shootingStar':
        _shootingStar = value;
        break;
      case 'eveningStar':
        _eveningStar = value;
        break;
      case 'bearishEngulfing':
        _bearishEngulfing = value;
        break;
      case 'blackCloudTops':
        _blackCloudTops = value;
        break;
      case 'pregnant':
        _pregnant = value;
        break;
      case 'reversingHammer':
        _reversingHammer = value;
        break;
      case 'restoreJustice':
        _restoreJustice = value;
        break;
      case 'narrowFinish':
        _narrowFinish = value;
        break;
      case 'upperLargeVolume':
        _upperLargeVolume = value;
        break;
      case 'downNarrowVolume':
        _downNarrowVolume = value;
        break;
      case 'upsideVolume':
        _upsideVolume = value;
        break;
      case 'heavenRule':
        _heavenRule = value;
        break;
      case 'lowFundsInflow':
        _lowFundsInflow = value;
        break;
      case 'highFundsOutflow':
        _highFundsOutflow = value;
        break;
      case 'upper8Days':
        _upper8Days = value;
        break;
      case 'upper9Days':
        _upper9Days = value;
        break;
      case 'upper4Days':
        _upper4Days = value;
        break;
      case 'down7Days':
        _down7Days = value;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('技术指标筛选'),
        actions: [
          if (_activeFilterCount > 0)
            TextButton(
              onPressed: _clearAll,
              child: Text('清除($_activeFilterCount)'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordCtrl,
                    decoration: InputDecoration(
                      hintText: '股票名称或代码（可选）',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _activeFilterCount > 0 ? _search : null,
                  child: const Text('筛选'),
                ),
              ],
            ),
          ),
          // 条件提示
          if (_activeFilterCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '已选 $_activeFilterCount 个条件，选中的条件之间是 AND 关系',
                style: TextStyle(fontSize: 11, color: theme.disabledColor),
              ),
            ),
          const SizedBox(height: 4),

          // 筛选条件（可折叠）
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (_activeFilterCount == 0 && !_searched)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 64,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '选择筛选条件',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '从下方勾选技术指标或K线形态条件\n选中的条件之间是 AND 关系\n然后点击"筛选"查看结果',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.disabledColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_searched) ...[
                  // 快速预设
                  SliverToBoxAdapter(
                    child: _buildQuickPresets(theme),
                  ),
                  ..._filterGroups.map((g) => _buildFilterGroup(g, theme)),
                ],

                // 搜索结果
                if (_searched)
                  _results.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: theme.disabledColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '未找到符合条件的股票',
                                  style: TextStyle(
                                    color: theme.disabledColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearAll,
                                  child: const Text('修改筛选条件'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: Row(
                              children: [
                                Text(
                                  '共 ${_results.length} 只股票',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const Spacer(),
                                // 排序控件
                                _sortButton(theme, '涨幅', 'CHANGE_RATE'),
                                const SizedBox(width: 4),
                                _sortButton(theme, '换手', 'TURNOVERRATE'),
                                const SizedBox(width: 4),
                                _sortButton(theme, '价格', 'NEW_PRICE'),
                              ],
                            ),
                          ),
                        ),
                if (_searched)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildResultItem(_getSortedResults()[i], theme),
                      childCount: _getSortedResults().length,
                    ),
                  ),

                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),

                // 底部间距
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresets(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速预设',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.local_fire_department, size: 16),
                label: const Text('强势突破', style: TextStyle(fontSize: 12)),
                onPressed: () => _applyPreset(['powerFulgun', 'breakThrough', 'upsideVolume']),
                backgroundColor: Colors.red.withValues(alpha: 0.06),
              ),
              ActionChip(
                avatar: const Icon(Icons.show_chart, size: 16),
                label: const Text('技术金叉', style: TextStyle(fontSize: 12)),
                onPressed: () => _applyPreset(['macdGoldenFork', 'kdjGoldenFork', 'longAvgArray']),
                backgroundColor: Colors.blue.withValues(alpha: 0.06),
              ),
              ActionChip(
                avatar: const Icon(Icons.trending_up, size: 16),
                label: const Text('连涨放量', style: TextStyle(fontSize: 12)),
                onPressed: () => _applyPreset(['upper4Days', 'upperLargeVolume']),
                backgroundColor: Colors.green.withValues(alpha: 0.06),
              ),
              ActionChip(
                avatar: const Icon(Icons.payments, size: 16),
                label: const Text('资金流入', style: TextStyle(fontSize: 12)),
                onPressed: () => _applyPreset(['lowFundsInflow', 'heavenRule']),
                backgroundColor: Colors.purple.withValues(alpha: 0.06),
              ),
            ],
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  void _applyPreset(List<String> keys) {
    setState(() {
      _clearAll();
      for (final key in keys) {
        _setFilter(key, true);
      }
    });
  }

  Widget _buildFilterGroup(_FilterGroup group, ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: group.filters.map((f) {
                final selected = _getFilterValue(f.key);
                return FilterChip(
                  label: Text(f.label, style: const TextStyle(fontSize: 12)),
                  avatar: Icon(f.icon, size: 16),
                  selected: selected,
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) {
                    setState(() => _setFilter(f.key, v));
                  },
                );
              }).toList(),
            ),
            const Divider(height: 20),
          ],
        ),
      ),
    );
  }

  bool _getFilterValue(String key) {
    switch (key) {
      case 'macdGoldenFork':
        return _macdGoldenFork;
      case 'kdjGoldenFork':
        return _kdjGoldenFork;
      case 'longAvgArray':
        return _longAvgArray;
      case 'shortAvgArray':
        return _shortAvgArray;
      case 'breakUpMa5Days':
        return _breakUpMa5Days;
      case 'breakThrough':
        return _breakThrough;
      case 'oneDayangLine':
        return _oneDayangLine;
      case 'twoDayangLines':
        return _twoDayangLines;
      case 'powerFulgun':
        return _powerFulgun;
      case 'riseSun':
        return _riseSun;
      case 'firstDawn':
        return _firstDawn;
      case 'morningStar':
        return _morningStar;
      case 'shootingStar':
        return _shootingStar;
      case 'eveningStar':
        return _eveningStar;
      case 'bearishEngulfing':
        return _bearishEngulfing;
      case 'blackCloudTops':
        return _blackCloudTops;
      case 'pregnant':
        return _pregnant;
      case 'reversingHammer':
        return _reversingHammer;
      case 'restoreJustice':
        return _restoreJustice;
      case 'narrowFinish':
        return _narrowFinish;
      case 'upperLargeVolume':
        return _upperLargeVolume;
      case 'downNarrowVolume':
        return _downNarrowVolume;
      case 'upsideVolume':
        return _upsideVolume;
      case 'heavenRule':
        return _heavenRule;
      case 'lowFundsInflow':
        return _lowFundsInflow;
      case 'highFundsOutflow':
        return _highFundsOutflow;
      case 'upper8Days':
        return _upper8Days;
      case 'upper9Days':
        return _upper9Days;
      case 'upper4Days':
        return _upper4Days;
      case 'down7Days':
        return _down7Days;
      default:
        return false;
    }
  }

  Widget _sortButton(ThemeData theme, String label, String field) {
    final active = _sortField == field;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortField == field) {
            _sortAsc = !_sortAsc;
          } else {
            _sortField = field;
            _sortAsc = field == 'CHANGE_RATE' ? false : false;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? theme.colorScheme.primary : theme.disabledColor,
              ),
            ),
            if (active)
              Icon(
                _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSortedResults() {
    final sorted = List<Map<String, dynamic>>.from(_results);
    sorted.sort((a, b) {
      final va = _toDouble(a[_sortField]);
      final vb = _toDouble(b[_sortField]);
      return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
    });
    return sorted;
  }

  Widget _buildResultItem(Map<String, dynamic> item, ThemeData theme) {
    final code = item['SECUCODE'] as String? ?? '';
    final name = item['SECURITY_NAME_ABBR'] as String? ?? '';
    final price = _toDouble(item['NEW_PRICE']);
    final changeRate = _toDouble(item['CHANGE_RATE']);
    final industry = item['INDUSTRY'] as String? ?? '';
    final turnoverRate = _toDouble(item['TURNOVERRATE']);
    final isUp = changeRate >= 0;

    final amplitude = _toDouble(item['AMPLITUDE']);
    final volumeRatio = _toDouble(item['VOLUME_RATIO']);
    final amount = _toDouble(item['AMOUNT']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailPage.fromCode(code, name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 股票信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              code.replaceAll(RegExp(r'\.(SZ|SH|BJ)$'), ''),
                              style: TextStyle(
                                color: theme.disabledColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (industry.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  industry,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.disabledColor,
                                  ),
                                ),
                              ),
                            if (turnoverRate > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '换手 ${turnoverRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                            if (amplitude > 0 && amplitude <= 50) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.swap_vert, size: 10, color: theme.disabledColor),
                              Text(
                                '${amplitude.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: amplitude > 5 ? Colors.orange : theme.disabledColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 价格和涨幅
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price > 0 ? price.toStringAsFixed(2) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isUp ? Colors.red : Colors.green,
                        ),
                      ),
                      Text(
                        '${isUp ? '+' : ''}${changeRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isUp ? Colors.red : Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 扩展信息行
              const SizedBox(height: 6),
              Row(
                children: [
                  if (volumeRatio > 0)
                    _miniTag(
                      '量比 ${volumeRatio.toStringAsFixed(2)}',
                      volumeRatio > 2 ? Colors.orange : theme.disabledColor,
                    ),
                  if (amount > 0) ...[
                    const SizedBox(width: 6),
                    _miniTag(
                      '成交 ${_formatAmount(amount)}',
                      theme.disabledColor,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${_toDouble(item['HIGH_PRICE']).toStringAsFixed(2)} / ${_toDouble(item['LOW_PRICE']).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: theme.disabledColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  String _formatAmount(double value) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}万';
    }
    return value.toStringAsFixed(0);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _FilterGroup {
  final String name;
  final List<_FilterDef> filters;
  const _FilterGroup(this.name, this.filters);
}

class _FilterDef {
  final String key;
  final String label;
  final IconData icon;
  const _FilterDef(this.key, this.label, this.icon);
}
