import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kline_data.dart';

/// K线图组件（支持十字光标 + 捏合缩放 + 水平滚动）
class KLineChart extends StatefulWidget {
  final List<KLineData> data;
  final double height;
  final Brightness? brightness;

  const KLineChart({
    super.key,
    required this.data,
    this.height = 400,
    this.brightness,
  });

  @override
  State<KLineChart> createState() => _KLineChartState();
}

class _KLineChartState extends State<KLineChart> {
  // 可见窗口状态
  int _visibleCount = 0; // 0 = 自动（全部显示）
  int _centerIndex = 0; // 可视区域中心点在完整数据中的下标

  // 十字光标
  int? _crosshairIndex;

  // 缩放手势
  double? _baseScale;
  int? _baseVisibleCount;

  // 水平拖动滚动
  bool _isDragging = false;
  int? _dragStartCenterIndex;
  double? _dragStartX;

  // 轻触十字光标（2秒后自动消失）
  int? _tapCrosshairIndex;
  Timer? _tapCrosshairTimer;

  // 记录父容器宽度，用于拖动计算
  double _parentWidth = 0;

  bool get _isZoomedIn => _visibleCount < widget.data.length;

  @override
  void initState() {
    super.initState();
    _resetView();
  }

  @override
  void didUpdateWidget(KLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resetView();
    }
  }

  @override
  void dispose() {
    _tapCrosshairTimer?.cancel();
    super.dispose();
  }

  void _resetView() {
    if (widget.data.isEmpty) return;
    setState(() {
      _visibleCount = widget.data.length;
      _centerIndex = widget.data.length - 1;
      _crosshairIndex = null;
      _tapCrosshairIndex = null;
    });
  }

  int get _startIndex {
    if (widget.data.isEmpty) return 0;
    if (_visibleCount >= widget.data.length) return 0;
    final maxStart = widget.data.length - _visibleCount;
    final center = _centerIndex.clamp(0, widget.data.length - 1);
    return (center - _visibleCount ~/ 2).clamp(0, maxStart);
  }

  int get _endIndex =>
      (_startIndex + _visibleCount).clamp(0, widget.data.length);

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('暂无K线数据')),
      );
    }
    final brightness = widget.brightness ?? Theme.of(context).brightness;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _parentWidth = constraints.maxWidth;
          return GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onLongPressStart: (d) => _onCrosshairStart(d, constraints),
            onLongPressMoveUpdate: (d) => _onCrosshairMove(d, constraints),
            onLongPressEnd: (_) => _onCrosshairEnd(),
            onTapUp: (details) => _onTapCrosshair(details, constraints),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _KLineChartPainter(
                    data: widget.data,
                    startIndex: _startIndex,
                    endIndex: _endIndex,
                    crosshairIndex:
                        _crosshairIndex ?? _tapCrosshairIndex,
                    brightness: brightness,
                    totalDataLength: widget.data.length,
                    isZoomedIn: _isZoomedIn,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- 缩放 + 拖动（统一通过 ScaleGestureRecognizer） ----

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount == 1 && _isZoomedIn) {
      // 单指水平拖动
      _isDragging = true;
      _dragStartCenterIndex = _centerIndex;
      _dragStartX = details.localFocalPoint.dx;
    } else {
      // 双指缩放
      _baseScale = 1.0;
      _baseVisibleCount = _visibleCount;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isDragging) {
      _onDragUpdate(details);
    } else if (details.pointerCount >= 2) {
      _onZoomUpdate(details);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isDragging) {
      _isDragging = false;
      _snapToLatest();
    }
    _baseScale = null;
    _baseVisibleCount = null;
    _dragStartCenterIndex = null;
    _dragStartX = null;
  }

  /// 水平拖动更新，将手指位移映射为蜡烛位置偏移
  void _onDragUpdate(ScaleUpdateDetails details) {
    if (!_isZoomedIn) return;
    if (_dragStartCenterIndex == null || _dragStartX == null) return;

    final dataLen = widget.data.length;
    if (dataLen == 0) return;

    const plotLeft = _KLineChartPainter.leftPadding;
    const plotPad = plotLeft + _KLineChartPainter.rightPadding;
    final plotW = _parentWidth - plotPad;
    final candleW = _visibleCount > 0 ? plotW / _visibleCount : plotW;

    final deltaX = details.localFocalPoint.dx - _dragStartX!;
    final deltaCandles = (deltaX / candleW).round();

    setState(() {
      _centerIndex = (_dragStartCenterIndex! - deltaCandles)
          .clamp(0, dataLen - 1);
    });
  }

  /// 拖动结束后，若靠近最新数据区域（右边缘3根蜡烛内），自动回弹对齐
  void _snapToLatest() {
    if (!_isZoomedIn) return;
    const snapThreshold = 3;
    if (_endIndex >= widget.data.length - snapThreshold) {
      setState(() {
        _centerIndex = widget.data.length - 1 - _visibleCount ~/ 2;
      });
    }
  }

  /// 双指缩放
  void _onZoomUpdate(ScaleUpdateDetails details) {
    if (_baseScale == null) return;
    final dataLen = widget.data.length;
    if (dataLen == 0) return;

    final scale = details.scale;
    final minVisible = dataLen < 10 ? dataLen : 10;
    final newCount =
        (_baseVisibleCount! / scale).round().clamp(minVisible, dataLen);
    if (newCount == _visibleCount) return;

    setState(() {
      _visibleCount = newCount;
      _centerIndex = _centerIndex.clamp(0, widget.data.length - 1);
      _baseScale = scale;
      _baseVisibleCount = newCount;
    });
  }

  // ---- 长按十字光标（持续显示） ----

  void _onCrosshairStart(
      LongPressStartDetails details, BoxConstraints constraints) {
    _updateCrosshair(details.localPosition, constraints);
  }

  void _onCrosshairMove(
      LongPressMoveUpdateDetails details, BoxConstraints constraints) {
    _updateCrosshair(details.localPosition, constraints);
  }

  void _onCrosshairEnd() {
    setState(() => _crosshairIndex = null);
  }

  // ---- 轻触十字光标（2秒自动消失） ----

  void _onTapCrosshair(TapUpDetails details, BoxConstraints constraints) {
    final idx = _calcCrosshairIndex(details.localPosition, constraints);
    if (idx != null) {
      _tapCrosshairTimer?.cancel();
      setState(() => _tapCrosshairIndex = idx);
      _tapCrosshairTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _tapCrosshairIndex = null);
        }
      });
    }
  }

  // ---- 十字光标计算 ----

  int? _calcCrosshairIndex(Offset localPos, BoxConstraints constraints) {
    final w = constraints.maxWidth;
    const plotLeft = _KLineChartPainter.leftPadding;
    final plotRight = w - _KLineChartPainter.rightPadding;
    final plotW = plotRight - plotLeft;
    final candleW = _visibleCount > 0 ? plotW / _visibleCount : plotW;

    final x = localPos.dx;
    if (x < plotLeft || x > plotRight) return null;

    final inViewIndex =
        ((x - plotLeft) / candleW).floor().clamp(0, _visibleCount - 1);
    final dataIndex = _startIndex + inViewIndex;
    if (dataIndex >= 0 && dataIndex < widget.data.length) {
      return dataIndex;
    }
    return null;
  }

  void _updateCrosshair(Offset localPos, BoxConstraints constraints) {
    final idx = _calcCrosshairIndex(localPos, constraints);
    setState(() => _crosshairIndex = idx);
  }
}

/// K线图绘制器
class _KLineChartPainter extends CustomPainter {
  final List<KLineData> data;
  final int startIndex;
  final int endIndex;
  final int? crosshairIndex;
  final Brightness brightness;
  final int totalDataLength;
  final bool isZoomedIn;

  // 布局常量
  static const double leftPadding = 50;
  static const double rightPadding = 10;
  static const double bottomPadding = 30;
  static const double volumeRatio = 0.25;

  _KLineChartPainter({
    required this.data,
    this.startIndex = 0,
    this.endIndex = 0,
    this.crosshairIndex,
    this.brightness = Brightness.light,
    this.totalDataLength = 0,
    this.isZoomedIn = false,
  });

  late double _w;
  late double _h;
  late double _candleAreaH;
  late double _volumeAreaH;
  late double _plotLeft;
  late double _plotRight;
  late double _plotW;
  late double _maxPrice;
  late double _minPrice;
  late double _priceRange;
  late double _maxVolume;
  late double _candleW;

  late List<double?> _ma5;
  late List<double?> _ma10;
  late List<double?> _ma20;
  late List<double?> _ma30;

  bool get _isDark => brightness == Brightness.dark;

  int get _visibleCount => endIndex - startIndex;

  // 主题颜色
  Color get _gridColor =>
      _isDark ? Colors.white24 : Colors.black12;
  Color get _axisColor =>
      _isDark ? Colors.white38 : Colors.grey[500]!;
  Color get _borderColor =>
      _isDark ? Colors.white24 : Colors.black26;
  Color get _crosshairColor =>
      _isDark ? Colors.blueGrey[300]! : Colors.blueGrey;
  Color get _tooltipBgColor =>
      _isDark ? const Color(0xF0202020) : const Color(0xF0FFFFFF);
  Color get _tooltipTextColor =>
      _isDark ? Colors.white : Colors.black87;
  Color get _candleUpColor => const Color(0xFFE53935); // 中国股市：红涨
  Color get _candleDownColor => const Color(0xFF00BFA5); // 中国股市：绿跌

  void _computeLayout(Size size) {
    _w = size.width;
    _h = size.height;
    _plotLeft = leftPadding;
    _plotRight = _w - rightPadding;
    _plotW = _plotRight - _plotLeft;
    _candleAreaH = _h * (1 - volumeRatio) - bottomPadding;
    _volumeAreaH = _h * volumeRatio - bottomPadding;
    _candleW = _visibleCount > 0 ? _plotW / _visibleCount : _plotW;
  }

  void _computeExtremes() {
    _maxPrice = -double.infinity;
    _minPrice = double.infinity;
    _maxVolume = 0;

    for (int i = startIndex; i < endIndex && i < data.length; i++) {
      final k = data[i];
      if (k.high > _maxPrice) _maxPrice = k.high;
      if (k.low < _minPrice) _minPrice = k.low;
      if (k.volume > _maxVolume) _maxVolume = k.volume;
    }

    final pad = (_maxPrice - _minPrice) * 0.05;
    if (pad == 0) {
      _maxPrice += 1;
      _minPrice -= 1;
    } else {
      _maxPrice += pad;
      _minPrice -= pad;
    }
    _priceRange = _maxPrice - _minPrice;
    if (_maxVolume == 0) _maxVolume = 1;
  }

  void _computeMA() {
    final closes = data.map((k) => k.close).toList();
    _ma5 = _sma(closes, 5);
    _ma10 = _sma(closes, 10);
    _ma20 = _sma(closes, 20);
    _ma30 = _sma(closes, 30);
  }

  List<double?> _sma(List<double> values, int period) {
    if (values.length < period) return List.filled(values.length, null);
    final result = List<double?>.filled(values.length, null);
    double sum = 0;
    for (int i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period - 1) {
        result[i] = sum / period;
        sum -= values[i - period + 1];
      }
    }
    return result;
  }

  double _priceToY(double price) {
    return _candleAreaH -
        ((price - _minPrice) / _priceRange) * _candleAreaH;
  }

  double _volumeToH(double volume) => (volume / _maxVolume) * _volumeAreaH;

  /// visible 数据中的下标 → x 坐标
  double _indexToX(int dataIndex) {
    final vi = dataIndex - startIndex;
    return _plotLeft + vi * _candleW + _candleW / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || _visibleCount <= 0) return;

    _computeLayout(size);
    _computeExtremes();
    _computeMA();

    _drawBackground(canvas);
    _drawGrid(canvas);
    _drawVolumeBars(canvas);
    _drawCandles(canvas);
    _drawMALines(canvas);
    _drawAxisLabels(canvas);
    _drawBorder(canvas);

    if (crosshairIndex != null) {
      _drawCrosshair(canvas);
    }

    if (isZoomedIn && totalDataLength > 0) {
      _drawScrollIndicator(canvas);
    }
  }

  // ---- 背景 ----

  void _drawBackground(Canvas canvas) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          if (_isDark)
            Colors.white.withValues(alpha: 0.03)
          else
            Colors.grey.withValues(alpha: 0.04),
          if (_isDark)
            Colors.white.withValues(alpha: 0.01)
          else
            Colors.grey.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(_plotLeft, 0, _plotW, _candleAreaH));
    canvas.drawRect(
      Rect.fromLTWH(_plotLeft, 0, _plotW, _candleAreaH),
      bgPaint,
    );
  }

  // ---- 网格 ----

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = _candleAreaH * i / 5;
      canvas.drawLine(Offset(_plotLeft, y), Offset(_plotRight, y), paint);
    }
    for (int i = 0; i <= 2; i++) {
      final y =
          _candleAreaH + bottomPadding + _volumeAreaH * i / 2;
      canvas.drawLine(Offset(_plotLeft, y), Offset(_plotRight, y), paint);
    }
  }

  // ---- 蜡烛 ----

  void _drawCandles(Canvas canvas) {
    for (int i = startIndex; i < endIndex && i < data.length; i++) {
      final k = data[i];
      final cx = _indexToX(i);
      final halfW = (_candleW * 0.35).clamp(1.0, 20.0);
      final yHigh = _priceToY(k.high);
      final yLow = _priceToY(k.low);
      final yOpen = _priceToY(k.open);
      final yClose = _priceToY(k.close);

      final isUp = k.isUp;
      // 中国股市惯例：红涨绿跌
      final color = isUp ? _candleUpColor : _candleDownColor;

      // 高亮选中的蜡烛
      final isCrosshair = crosshairIndex == i;
      if (isCrosshair) {
        final hlPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.2);
        canvas.drawRect(
          Rect.fromLTRB(
              cx - halfW - 2, yHigh - 2, cx + halfW + 2, yLow + 2),
          hlPaint,
        );
      }

      // 影线
      final wickPaint = Paint()..color = color..strokeWidth = 1;
      canvas.drawLine(
          Offset(cx, yHigh),
          Offset(cx, isUp ? yClose : yOpen),
          wickPaint);
      canvas.drawLine(
          Offset(cx, isUp ? yOpen : yClose),
          Offset(cx, yLow),
          wickPaint);

      // 实体
      final rect = Rect.fromLTRB(
          cx - halfW,
          math.min(yOpen, yClose),
          cx + halfW,
          math.max(yOpen, yClose));
      if (rect.height < 0.5) {
        canvas.drawLine(
            Offset(cx - halfW, yOpen),
            Offset(cx + halfW, yOpen),
            wickPaint..strokeWidth = 1.5);
      } else {
        canvas.drawRect(rect, Paint()..color = color);
      }
    }
  }

  // ---- 成交量 ----

  void _drawVolumeBars(Canvas canvas) {
    final volumeBaseY = _candleAreaH + bottomPadding;
    for (int i = startIndex; i < endIndex && i < data.length; i++) {
      final k = data[i];
      final cx = _indexToX(i);
      final halfW = (_candleW * 0.3).clamp(1.0, 15.0);
      final barH = _volumeToH(k.volume);
      final color = k.isUp ? _candleUpColor : _candleDownColor;
      canvas.drawRect(
        Rect.fromLTRB(
            cx - halfW,
            volumeBaseY + _volumeAreaH - barH,
            cx + halfW,
            volumeBaseY + _volumeAreaH),
        Paint()..color = color.withValues(alpha: 0.5),
      );
    }
  }

  // ---- 均线 ----

  void _drawMALine(
      Canvas canvas, List<double?> maValues, Color color) {
    final path = Path();
    bool started = false;
    for (int i = startIndex; i < endIndex && i < maValues.length; i++) {
      final v = maValues[i];
      if (v == null) continue;
      final x = _indexToX(i);
      final y = _priceToY(v);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke);
  }

  void _drawMALines(Canvas canvas) {
    _drawMALine(canvas, _ma5, const Color(0xFFFFC107));
    _drawMALine(canvas, _ma10, const Color(0xFF2196F3));
    _drawMALine(canvas, _ma20, const Color(0xFFFF9800));
    _drawMALine(canvas, _ma30, const Color(0xFF4CAF50));
  }

  // ---- 十字光标 ----

  void _drawCrosshair(Canvas canvas) {
    final dataIdx = crosshairIndex!;
    if (dataIdx < 0 || dataIdx >= data.length) return;

    final k = data[dataIdx];
    final cx = _indexToX(dataIdx);

    final linePaint = Paint()
      ..color = _crosshairColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 竖线
    canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, _candleAreaH + bottomPadding + _volumeAreaH),
        linePaint);
    // 横线（以收盘价为基准）
    final closeY = _priceToY(k.close);
    canvas.drawLine(
        Offset(_plotLeft, closeY),
        Offset(_plotRight, closeY),
        linePaint);

    // 右侧价格标签
    _drawCrosshairLabel(canvas, k, dataIdx, cx);
  }

  void _drawCrosshairLabel(
      Canvas canvas, KLineData k, int dataIdx, double cx) {
    final bgPaint = Paint()..color = _tooltipBgColor;
    final borderPaint = Paint()
      ..color = _crosshairColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 背景阴影
    final shadowPaint = Paint()
      ..color = _isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final lines = <String>[
      '日期: ${_formatDate(k.day)}',
      '开: ${k.open.toStringAsFixed(2)}  收: ${k.close.toStringAsFixed(2)}',
      '高: ${k.high.toStringAsFixed(2)}  低: ${k.low.toStringAsFixed(2)}',
      '涨幅: ${k.changePercent.toStringAsFixed(2)}%',
      '成交量: ${_formatVolume(k.volume)}',
    ];
    // 添加 MA 值
    if (k.ma != null) {
      final maVals = k.ma!;
      final parts = <String>[];
      maVals.forEach((period, val) {
        parts.add('MA$period: ${val.toStringAsFixed(2)}');
      });
      if (parts.isNotEmpty) {
        lines.add(parts.join('  '));
      } else {
        if (dataIdx < _ma5.length && _ma5[dataIdx] != null) {
          lines.add('MA5: ${_ma5[dataIdx]!.toStringAsFixed(2)}');
        }
        if (dataIdx < _ma10.length && _ma10[dataIdx] != null) {
          lines.add('MA10: ${_ma10[dataIdx]!.toStringAsFixed(2)}');
        }
      }
    } else {
      lines.add(
          'MA5: ${_safeMa(_ma5, dataIdx)}  MA10: ${_safeMa(_ma10, dataIdx)}');
      lines.add(
          'MA20: ${_safeMa(_ma20, dataIdx)}  MA30: ${_safeMa(_ma30, dataIdx)}');
    }

    // 定位：优先右侧，太靠右则放左侧
    const tooltipW = 180.0;
    final tooltipH = lines.length * 18.0 + 12.0;
    final tooltipX = (cx + 20 + tooltipW < _plotRight)
        ? cx + 20
        : cx - 20 - tooltipW;
    const tooltipY = 8.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
      const Radius.circular(8),
    );
    // Shadow effect
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawRRect(rect, shadowPaint);
    canvas.restore();

    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    final ts = TextStyle(
        fontSize: 10, color: _tooltipTextColor, height: 1.4);
    double ty = tooltipY + 6;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(text: line, style: ts),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tooltipX + 6, ty));
      ty += 18;
    }

    // 右侧收盘价标签
    final closeY = _priceToY(k.close);
    final label = k.close.toStringAsFixed(2);
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelBg = Paint()..color = const Color(0xFF2196F3);
    canvas.drawRect(
      Rect.fromLTWH(_plotRight, closeY - labelTp.height / 2,
          labelTp.width + 6, labelTp.height),
      labelBg,
    );
    labelTp.paint(
        canvas, Offset(_plotRight + 3, closeY - labelTp.height / 2));
  }

  String _safeMa(List<double?> ma, int dataIdx) {
    if (dataIdx >= 0 &&
        dataIdx < ma.length &&
        ma[dataIdx] != null) {
      return ma[dataIdx]!.toStringAsFixed(2);
    }
    return '—';
  }

  // ---- 轴标签 ----

  void _drawAxisLabels(Canvas canvas) {
    final style = TextStyle(fontSize: 10, color: _axisColor);

    // 价格标签（左侧）
    for (int i = 0; i <= 5; i++) {
      final price = _maxPrice - (_priceRange * i / 5);
      final y = _candleAreaH * i / 5;
      final tp = TextPainter(
        text: TextSpan(text: price.toStringAsFixed(2), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(_plotLeft - tp.width - 4, y - tp.height / 2));
    }

    // 成交量单位
    final volTp = TextPainter(
      text: TextSpan(
          text: _formatVolume(_maxVolume), style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    volTp.paint(
        canvas,
        Offset(_plotLeft - volTp.width - 4,
            _candleAreaH + bottomPadding));

    // 日期标签
    if (_visibleCount > 0) {
      final count = _visibleCount;
      final step = (count / 5).ceil().clamp(1, count);
      for (int i = startIndex;
          i < endIndex && i < data.length;
          i += step) {
        final label = _formatDate(data[i].day);
        final x = _indexToX(i);
        final tp = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x - tp.width / 2, _h - bottomPadding + 4));
      }
    }
  }

  void _drawBorder(Canvas canvas) {
    final paint = Paint()
      ..color = _borderColor
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(_plotLeft, 0), Offset(_plotRight, 0), paint);
    canvas.drawLine(Offset(_plotLeft, _candleAreaH),
        Offset(_plotRight, _candleAreaH), paint);
    canvas.drawLine(
        Offset(_plotLeft, 0), Offset(_plotLeft, _candleAreaH), paint);
    canvas.drawLine(Offset(_plotRight, 0),
        Offset(_plotRight, _candleAreaH), paint);
  }

  // ---- 滚动位置指示器 ----

  void _drawScrollIndicator(Canvas canvas) {
    if (totalDataLength <= _visibleCount) return;

    final barY = _h - bottomPadding + 10;
    final barLeft = _plotLeft;
    final barRight = _plotRight;
    final barWidth = barRight - barLeft;
    const barHeight = 3.0;

    // 背景轨道
    final trackPaint = Paint()
      ..color = _isDark ? Colors.white24 : Colors.black12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, barY, barWidth, barHeight),
        const Radius.circular(1.5),
      ),
      trackPaint,
    );

    // 滑块
    final visibleRatio = _visibleCount / totalDataLength;
    final sliderWidth =
        (barWidth * visibleRatio).clamp(10.0, barWidth);
    final sliderMaxOffset = totalDataLength - _visibleCount;
    final sliderLeft = barLeft +
        (barWidth - sliderWidth) *
            (startIndex / sliderMaxOffset);

    final sliderPaint = Paint()
      ..color = _isDark ? Colors.white54 : Colors.grey[600]!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            sliderLeft, barY, sliderWidth, barHeight),
        const Radius.circular(1.5),
      ),
      sliderPaint,
    );

    // "← 滑动查看更多" 提示（仅在靠近最新数据区域时显示）
    final isNearEnd = endIndex >= totalDataLength - 3;
    if (isNearEnd) {
      final hintTp = TextPainter(
        text: TextSpan(
          text: '← 滑动查看更多',
          style: TextStyle(
              fontSize: 9, color: _axisColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hintTp.paint(
          canvas,
          Offset(barLeft, barY + barHeight + 3));
    }
  }

  String _formatDate(String day) {
    if (day.length >= 10) return day.substring(5, 10);
    if (day.length == 8) {
      return '${day.substring(4, 6)}-${day.substring(6, 8)}';
    }
    return day;
  }

  String _formatVolume(double vol) {
    if (vol >= 100000000) {
      return '${(vol / 100000000).toStringAsFixed(1)}亿';
    }
    if (vol >= 10000) {
      return '${(vol / 10000).toStringAsFixed(1)}万';
    }
    return vol.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _KLineChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.startIndex != startIndex ||
      oldDelegate.endIndex != endIndex ||
      oldDelegate.crosshairIndex != crosshairIndex ||
      oldDelegate.brightness != brightness ||
      oldDelegate.isZoomedIn != isZoomedIn ||
      oldDelegate.totalDataLength != totalDataLength;
}

/// MA 图例
class KLineLegend extends StatelessWidget {
  const KLineLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _item('MA5', const Color(0xFFFFC107)),
        const SizedBox(width: 12),
        _item('MA10', const Color(0xFF2196F3)),
        const SizedBox(width: 12),
        _item('MA20', const Color(0xFFFF9800)),
        const SizedBox(width: 12),
        _item('MA30', const Color(0xFF4CAF50)),
      ],
    );
  }

  Widget _item(String label, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 2, color: c),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
