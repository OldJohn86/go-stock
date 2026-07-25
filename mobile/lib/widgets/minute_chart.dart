import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/minute_data.dart';

/// 分时图组件
class MinuteChart extends StatelessWidget {
  final List<MinuteData> data;
  final String date;
  final double preClose;
  final double height;

  const MinuteChart({
    super.key,
    required this.data,
    this.date = '',
    this.preClose = 0,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无分时数据')),
      );
    }
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _MinuteChartPainter(
              data: data,
              preClose: preClose,
              date: date,
            ),
          );
        },
      ),
    );
  }
}

class _MinuteChartPainter extends CustomPainter {
  final List<MinuteData> data;
  final double preClose;
  final String date;

  static const double leftPadding = 50;
  static const double rightPadding = 10;
  static const double bottomPadding = 30;
  static const double volumeRatio = 0.2;

  _MinuteChartPainter({
    required this.data,
    this.preClose = 0,
    this.date = '',
  });

  late double _w;
  late double _h;
  late double _plotLeft;
  late double _plotRight;
  late double _plotW;
  late double _priceAreaH;
  late double _volumeAreaH;
  late double _maxPrice;
  late double _minPrice;
  late double _priceRange;
  late double _maxVolume;
  late double _preClosePrice;

  void _computeLayout(Size size) {
    _w = size.width;
    _h = size.height;
    _plotLeft = leftPadding;
    _plotRight = _w - rightPadding;
    _plotW = _plotRight - _plotLeft;
    _priceAreaH = _h * (1 - volumeRatio) - bottomPadding;
    _volumeAreaH = _h * volumeRatio - bottomPadding;
  }

  void _computeExtremes() {
    _preClosePrice = preClose > 0 ? preClose : (data.isNotEmpty ? data.first.price : 0);

    _maxPrice = -double.infinity;
    _minPrice = double.infinity;
    _maxVolume = 0;

    for (final d in data) {
      if (d.price > _maxPrice) _maxPrice = d.price;
      if (d.price < _minPrice) _minPrice = d.price;
      if (d.volume > _maxVolume) _maxVolume = d.volume;
    }

    // 如果价格与昨收差距小，则基于昨收上下各留 1%
    final priceToPreClose = math.max(
      (_maxPrice - _preClosePrice).abs(),
      (_minPrice - _preClosePrice).abs(),
    );
    final margin = math.max(priceToPreClose * 0.1, _preClosePrice * 0.01);
    _maxPrice = math.max(_maxPrice, _preClosePrice) + margin;
    _minPrice = math.min(_minPrice, _preClosePrice) - margin;

    if (_maxPrice <= _minPrice) {
      _maxPrice = _preClosePrice * 1.01;
      _minPrice = _preClosePrice * 0.99;
    }

    _priceRange = _maxPrice - _minPrice;

    if (_maxVolume <= 0) _maxVolume = 1;
  }

  double _priceToY(double price) {
    return _priceAreaH -
        ((price - _minPrice) / _priceRange) * _priceAreaH;
  }

  double _volumeToH(double volume) {
    return (volume / _maxVolume) * _volumeAreaH;
  }

  double _indexToX(int index) {
    if (data.length <= 1) return _plotLeft + _plotW / 2;
    return _plotLeft + (index / (data.length - 1)) * _plotW;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _computeLayout(size);
    _computeExtremes();

    _drawBackground(canvas);
    _drawGrid(canvas);
    _drawPreCloseLine(canvas);
    _drawPriceLine(canvas);
    _drawVolumeBars(canvas);
    _drawAxisLabels(canvas);
  }

  void _drawBackground(Canvas canvas) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.withValues(alpha: 0.04),
          Colors.grey.withValues(alpha: 0.01),
        ],
      ).createShader(Rect.fromLTWH(_plotLeft, 0, _plotW, _priceAreaH));
    canvas.drawRect(
      Rect.fromLTWH(_plotLeft, 0, _plotW, _priceAreaH),
      bgPaint,
    );
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = _priceAreaH * i / 5;
      canvas.drawLine(
        Offset(_plotLeft, y),
        Offset(_plotRight, y),
        paint,
      );
    }

    // 成交量区域网格
    for (int i = 0; i <= 2; i++) {
      final y = _priceAreaH + bottomPadding + _volumeAreaH * i / 2;
      canvas.drawLine(
        Offset(_plotLeft, y),
        Offset(_plotRight, y),
        paint,
      );
    }
  }

  void _drawPreCloseLine(Canvas canvas) {
    final y = _priceToY(_preClosePrice);
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final dashPath = Path()
      ..moveTo(_plotLeft, y)
      ..lineTo(_plotRight, y);
    canvas.drawPath(dashPath, paint);

    // "昨收"标签 — 带背景
    final preCloseLabel = '昨收 ${_preClosePrice.toStringAsFixed(2)}';
    final labelTp = TextPainter(
      text: TextSpan(
        text: preCloseLabel,
        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelBg = Paint()..color = Colors.grey.withValues(alpha: 0.6);
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_plotRight, y - labelTp.height / 2 - 2, labelTp.width + 8, labelTp.height + 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(labelRect, labelBg);
    labelTp.paint(canvas, Offset(_plotRight + 4, y - labelTp.height / 2));
  }

  void _drawPriceLine(Canvas canvas) {
    if (data.isEmpty) return;

    // 填充区域
    final fillPath = Path();
    final firstX = _indexToX(0);
    final firstY = _priceToY(data.first.price);
    fillPath.moveTo(firstX, firstY);

    for (int i = 1; i < data.length; i++) {
      fillPath.lineTo(_indexToX(i), _priceToY(data[i].price));
    }

    final lastX = _indexToX(data.length - 1);
    fillPath.lineTo(lastX, _priceAreaH);
    fillPath.lineTo(firstX, _priceAreaH);
    fillPath.close();

    final isUp = data.last.price >= _preClosePrice;
    final fillColor = isUp ? const Color(0xFF00BFA5) : const Color(0xFFFF5252);

    // 填充
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // 价格线
    final linePath = Path();
    linePath.moveTo(firstX, firstY);
    for (int i = 1; i < data.length; i++) {
      linePath.lineTo(_indexToX(i), _priceToY(data[i].price));
    }

    // 阴影 glow
    final glowPaint = Paint()
      ..color = fillColor.withValues(alpha: 0.2)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);

    // 主画线
    canvas.drawPath(
      linePath,
      Paint()
        ..color = fillColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawVolumeBars(Canvas canvas) {
    final volumeBaseY = _priceAreaH + bottomPadding;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = _indexToX(i);
      final barH = _volumeToH(d.volume);
      final barW = (_plotW / data.length * 0.5).clamp(1.0, 8.0);

      final color = d.price >= _preClosePrice
          ? const Color(0xFF00BFA5)
          : const Color(0xFFFF5252);

      canvas.drawRect(
        Rect.fromLTRB(
          x - barW / 2,
          volumeBaseY + _volumeAreaH - barH,
          x + barW / 2,
          volumeBaseY + _volumeAreaH,
        ),
        Paint()..color = color.withValues(alpha: 0.5),
      );
    }
  }

  void _drawAxisLabels(Canvas canvas) {
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey[500]);

    // 价格标签
    for (int i = 0; i <= 5; i++) {
      final price = _maxPrice - (_priceRange * i / 5);
      final y = _priceAreaH * i / 5;
      final tp = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(2),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_plotLeft - tp.width - 4, y - tp.height / 2));
    }

    // 涨跌幅标签（右侧）
    for (int i = 0; i <= 5; i++) {
      final price = _maxPrice - (_priceRange * i / 5);
      final changePct = _preClosePrice > 0
          ? ((price - _preClosePrice) / _preClosePrice * 100)
          : 0.0;
      if (changePct.abs() > 0.05) {
        final y = _priceAreaH * i / 5;
        final cp = TextPainter(
          text: TextSpan(
            text: '${changePct >= 0 ? "+" : ""}${changePct.toStringAsFixed(2)}%',
            style: labelStyle.copyWith(
              color: changePct >= 0
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFFFF5252),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        cp.paint(canvas, Offset(_plotRight + 4, y - cp.height / 2));
      }
    }

    // 时间标签
    if (data.length > 1) {
      final indices = [
        0,
        (data.length * 0.25).round(),
        (data.length * 0.5).round(),
        (data.length * 0.75).round(),
        data.length - 1,
      ];
      for (final i in indices) {
        if (i >= data.length) continue;
        final label = data[i].time;
        final x = _indexToX(i);
        final tp = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(x - tp.width / 2, _h - bottomPadding + 4),
        );
      }
    }

    // 日期
    if (date.isNotEmpty) {
      final dateTp = TextPainter(
        text: TextSpan(
          text: date,
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dateTp.paint(canvas, Offset(_plotLeft, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _MinuteChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
