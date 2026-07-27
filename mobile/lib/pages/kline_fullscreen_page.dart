import 'package:flutter/material.dart';

import '../models/kline_data.dart';
import '../widgets/indicator_chart.dart';
import '../widgets/kline_chart.dart';

/// K线全屏页面 — 最大化展示区域，隐藏所有无关 UI
class KLineFullscreenPage extends StatefulWidget {
  final List<KLineData> data;
  final String stockName;
  final String stockCode;

  const KLineFullscreenPage({
    super.key,
    required this.data,
    this.stockName = '',
    this.stockCode = '',
  });

  @override
  State<KLineFullscreenPage> createState() => _KLineFullscreenPageState();
}

class _KLineFullscreenPageState extends State<KLineFullscreenPage>
    with WidgetsBindingObserver {
  bool _showControls = true;
  IndicatorType _indicatorType = IndicatorType.none;

  // 周期类型（从 detail page 传入简化版）
  final List<_KLineTypeOption> _klineTypes = const [
    _KLineTypeOption('日K', '101'),
    _KLineTypeOption('周K', '102'),
    _KLineTypeOption('月K', '103'),
    _KLineTypeOption('5分', '5'),
    _KLineTypeOption('15分', '15'),
    _KLineTypeOption('30分', '30'),
    _KLineTypeOption('60分', '60'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // K线图
            Padding(
              padding: EdgeInsets.only(
                top: _showControls ? 100 : 8,
                bottom: _showControls ? 80 : 8,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: KLineChart(
                      data: widget.data,
                      height: double.infinity,
                    ),
                  ),
                  if (_indicatorType != IndicatorType.none)
                    SizedBox(
                      height: 100,
                      child: IndicatorChart(
                        data: widget.data,
                        type: _indicatorType,
                        height: 100,
                      ),
                    ),
                ],
              ),
            ),

            // 顶部控制栏（点击切换显示/隐藏）
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: 0.95),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : Colors.black12,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 标题 + 关闭按钮
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: '关闭全屏',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              widget.stockName.isNotEmpty
                                  ? '${widget.stockName} - ${widget.stockCode}'
                                  : 'K线全屏',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 48), // 占位平衡
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 周期选择
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: _klineTypes.map((opt) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ChoiceChip(
                                label: Text(opt.label,
                                    style: const TextStyle(fontSize: 11)),
                                selected: false,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) {},
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // 指标切换
                      SizedBox(
                        height: 30,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            _chip('关闭', IndicatorType.none),
                            const SizedBox(width: 4),
                            _chip('MACD', IndicatorType.macd),
                            const SizedBox(width: 4),
                            _chip('KDJ', IndicatorType.kdj),
                            const SizedBox(width: 4),
                            _chip('RSI', IndicatorType.rsi),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 点击中间区域切换控制栏显示
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IndicatorType type) {
    final selected = _indicatorType == type;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 11, color: selected ? Colors.white : null)),
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.primary,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _indicatorType = type),
    );
  }
}

class _KLineTypeOption {
  final String label;
  final String type;
  const _KLineTypeOption(this.label, this.type);
}
