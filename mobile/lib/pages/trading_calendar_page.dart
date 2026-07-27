import 'package:flutter/material.dart';

import '../api/trading_api.dart';

/// 交易日历热力图 — 按月展示每日盈亏
class TradingCalendarPage extends StatefulWidget {
  const TradingCalendarPage({super.key});

  @override
  State<TradingCalendarPage> createState() => _TradingCalendarPageState();
}

class _TradingCalendarPageState extends State<TradingCalendarPage> {
  final _api = TradingApi();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, Map<String, dynamic>> _dailyData = {};
  bool _loading = false;
  String? _error;
  double _maxAbs = 1; // 用于颜色归一化
  String? _selectedDate;
  Map<String, dynamic>? _selectedDetail;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getDailyPnL(
        year: _currentMonth.year,
        month: _currentMonth.month,
      );
      final map = <String, Map<String, dynamic>>{};
      double max = 1;
      for (final item in data) {
        final date = item['date'] as String? ?? '';
        if (date.isNotEmpty) {
          map[date] = item;
          final net = (item['netAmount'] as num?)?.toDouble() ?? 0;
          if (net.abs() > max) max = net.abs();
        }
      }
      if (mounted) {
        setState(() {
          _dailyData = map;
          _maxAbs = max;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
      _selectedDetail = null;
    });
    _fetchData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
      _selectedDetail = null;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // 0=Sun

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_currentMonth.year}年${_currentMonth.month}月 交易日历',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '回到今天',
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
                _selectedDate = null;
                _selectedDetail = null;
              });
              _fetchData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份切换
          _buildMonthNav(theme),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('加载失败', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _fetchData,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 日历网格
                    _buildCalendarGrid(theme, daysInMonth, firstWeekday),
                    const SizedBox(height: 16),
                    // 图例
                    _buildLegend(theme),
                    const SizedBox(height: 16),
                    // 选中日期的详情
                    if (_selectedDetail != null) _buildDayDetail(theme),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
          ),
          Text(
            '${_currentMonth.year}年${_currentMonth.month}月',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, int daysInMonth, int firstWeekday) {
    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 星期标题
            Row(
              children: weekdays.map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.disabledColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 4),
            // 日期网格
            ..._buildWeeks(daysInMonth, firstWeekday, theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeeks(int daysInMonth, int firstWeekday, ThemeData theme) {
    final weeks = <Widget>[];
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentMonthStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

    int day = 1;
    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (int w = 0; w < 7; w++) {
        if ((day == 1 && w < firstWeekday) || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 44)));
        } else {
          final dateStr = '$currentMonthStr-${day.toString().padLeft(2, '0')}';
          final data = _dailyData[dateStr];
          final isToday = dateStr == todayStr;
          final hasData = data != null;
          final netAmount = hasData ? ((data['netAmount'] as num?)?.toDouble() ?? 0) : 0;

          Color? bgColor;
          if (hasData) {
            if (netAmount > 0) {
              // 盈利 - 红色系（A股红色=涨）
              final intensity = (netAmount / _maxAbs).clamp(0.0, 1.0);
              bgColor = Colors.red.withValues(alpha: 0.1 + intensity * 0.5);
            } else if (netAmount < 0) {
              // 亏损 - 绿色系
              final intensity = (netAmount.abs() / _maxAbs).clamp(0.0, 1.0);
              bgColor = Colors.green.withValues(alpha: 0.1 + intensity * 0.5);
            } else {
              bgColor = Colors.grey.withValues(alpha: 0.08);
            }
          }

          cells.add(
            Expanded(
              child: GestureDetector(
                onTap: hasData ? () {
                  setState(() {
                    _selectedDate = dateStr;
                    _selectedDetail = data;
                  });
                } : null,
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday
                        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                        : (_selectedDate == dateStr
                            ? Border.all(color: theme.colorScheme.secondary, width: 1)
                            : null),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          day++;
        }
      }
      weeks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: cells),
      ));
    }
    return weeks;
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(theme, '亏损', Colors.green.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        _legendItem(theme, '持平', Colors.grey.withValues(alpha: 0.2)),
        const SizedBox(width: 8),
        _legendItem(theme, '盈利', Colors.red.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _legendItem(ThemeData theme, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: theme.disabledColor)),
      ],
    );
  }

  Widget _buildDayDetail(ThemeData theme) {
    if (_selectedDetail == null) return const SizedBox();
    final detail = _selectedDetail!;
    final date = _selectedDate ?? '';
    final netAmount = (detail['netAmount'] as num?)?.toDouble() ?? 0;
    final buyAmount = (detail['buyAmount'] as num?)?.toDouble() ?? 0;
    final sellAmount = (detail['sellAmount'] as num?)?.toDouble() ?? 0;
    final tradeCount = (detail['tradeCount'] as num?)?.toInt() ?? 0;
    final isProfit = netAmount >= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isProfit ? Icons.trending_up : Icons.trending_down,
                  color: isProfit ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${isProfit ? '+' : ''}${netAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isProfit ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(theme, '买入金额', '¥${_formatAmount(buyAmount)}'),
            const SizedBox(height: 6),
            _detailRow(theme, '卖出金额', '¥${_formatAmount(sellAmount)}'),
            const SizedBox(height: 6),
            _detailRow(theme, '交易次数', '$tradeCount 笔'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.disabledColor, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  String _formatAmount(double amount) {
    final abs = amount.abs();
    if (abs >= 100000000) return '${(amount / 100000000).toStringAsFixed(2)}亿';
    if (abs >= 10000) return '${(amount / 10000).toStringAsFixed(2)}万';
    return amount.toStringAsFixed(2);
  }
}
