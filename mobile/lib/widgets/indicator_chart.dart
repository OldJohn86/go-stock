import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/kline_data.dart';
import '../utils/kline_indicators.dart';

/// 技术指标类型
enum IndicatorType { macd, kdj, rsi, none }

/// 技术指标子图
class IndicatorChart extends StatelessWidget {
  final List<KLineData> data;
  final IndicatorType type;
  final double height;

  const IndicatorChart({
    super.key,
    required this.data,
    required this.type,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (type == IndicatorType.none || data.length < 5) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _IndicatorPainter(data: data, type: type),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  final List<KLineData> data;
  final IndicatorType type;

  _IndicatorPainter({required this.data, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final left = 50.0, right = 16.0;
    final plotW = w - left - right;

    // 背景
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

    // 中线
    canvas.drawLine(
      Offset(left, h / 2),
      Offset(w - right, h / 2),
      Paint()..color = Colors.grey.withValues(alpha: 0.3)..strokeWidth = 0.5,
    );

    switch (type) {
      case IndicatorType.macd:
        _drawMacd(canvas, size, w, left, right, plotW);
        break;
      case IndicatorType.kdj:
        _drawKdj(canvas, size, w, left, right, plotW);
        break;
      case IndicatorType.rsi:
        _drawRsi(canvas, size, w, left, right, plotW);
        break;
      case IndicatorType.none:
        break;
    }
  }

  void _drawMacd(Canvas canvas, Size size, double fullW, double left, double right, double plotW) {
    final result = KlineIndicators.macd(data);
    final h = size.height;
    final len = result.dif.length;
    if (len == 0) return;

    final padTop = 12.0, padBottom = 16.0;
    final plotH = h - padTop - padBottom;

    // 找最大绝对值
    double maxAbs = 0;
    for (var i = 0; i < len; i++) {
      maxAbs = math.max(maxAbs, result.histogram[i].abs());
      maxAbs = math.max(maxAbs, result.dif[i].abs());
      maxAbs = math.max(maxAbs, result.dea[i].abs());
    }
    if (maxAbs == 0) maxAbs = 1;

    final scale = plotH / 2 / maxAbs;

    final paintHistUp = Paint()..color = Colors.red.withValues(alpha: 0.6);
    final paintHistDn = Paint()..color = Colors.green.withValues(alpha: 0.6);
    final paintDif = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paintDea = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pathDif = Path();
    final pathDea = Path();
    bool firstDif = true, firstDea = true;

    final candleW = len > 1 ? plotW / (len - 1) : plotW;

    for (var i = 0; i < len; i++) {
      final x = left + (len > 1 ? i / (len - 1) * plotW : plotW / 2);

      // 柱状图
      final hv = result.histogram[i] * scale;
      final cy = h / 2; // 中线
      if (hv != 0) {
        canvas.drawRect(
          Rect.fromLTRB(x - candleW * 0.3, hv > 0 ? cy - hv : cy, x + candleW * 0.3, hv > 0 ? cy : cy - hv),
          hv >= 0 ? paintHistUp : paintHistDn,
        );
      }

      // DIF
      final dy = h / 2 - result.dif[i] * scale;
      if (firstDif) {
        pathDif.moveTo(x, dy);
        firstDif = false;
      } else {
        pathDif.lineTo(x, dy);
      }

      // DEA
      final deaY = h / 2 - result.dea[i] * scale;
      if (firstDea) {
        pathDea.moveTo(x, deaY);
        firstDea = false;
      } else {
        pathDea.lineTo(x, deaY);
      }
    }

    canvas.drawPath(pathDif, paintDif);
    canvas.drawPath(pathDea, paintDea);

    // 标签
    _drawLabel(canvas, 'DIF', fullW - right - 2, padTop + 4, Colors.blue);
    _drawLabel(canvas, 'DEA', fullW - right - 2, padTop + 18, Colors.orange);
  }

  void _drawKdj(Canvas canvas, Size size, double fullW, double left, double right, double plotW) {
    final result = KlineIndicators.kdj(data);
    final h = size.height;
    final len = result.k.length;
    if (len == 0) return;

    final padTop = 12.0, padBottom = 16.0;
    final plotH = h - padTop - padBottom;

    // KDJ 范围 0-100
    const maxVal = 100.0;
    const minVal = 0.0;

    final paintK = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paintD = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paintJ = Paint()
      ..color = Colors.purple
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final pathK = Path(), pathD = Path(), pathJ = Path();
    bool firstK = true, firstD = true, firstJ = true;

    for (var i = 0; i < len; i++) {
      final x = left + (len > 1 ? i / (len - 1) * plotW : plotW / 2);
      final ky = padTop + ((maxVal - result.k[i]) / (maxVal - minVal)) * plotH;
      final dy = padTop + ((maxVal - result.d[i]) / (maxVal - minVal)) * plotH;
      final jy = padTop + ((maxVal - result.j[i]) / (maxVal - minVal)) * plotH;

      if (firstK) { pathK.moveTo(x, ky); firstK = false; }
      else { pathK.lineTo(x, ky); }
      if (firstD) { pathD.moveTo(x, dy); firstD = false; }
      else { pathD.lineTo(x, dy); }
      if (firstJ) { pathJ.moveTo(x, jy); firstJ = false; }
      else { pathJ.lineTo(x, jy); }
    }

    canvas.drawPath(pathK, paintK);
    canvas.drawPath(pathD, paintD);
    canvas.drawPath(pathJ, paintJ);

    _drawLabel(canvas, 'K', fullW - right - 2, padTop + 4, Colors.blue);
    _drawLabel(canvas, 'D', fullW - right - 2, padTop + 18, Colors.orange);
    _drawLabel(canvas, 'J', fullW - right - 2, padTop + 32, Colors.purple);
  }

  void _drawRsi(Canvas canvas, Size size, double fullW, double left, double right, double plotW) {
    final result = KlineIndicators.rsi(data);
    final h = size.height;
    final len = result.rsi6.length;
    if (len == 0) return;

    final padTop = 12.0, padBottom = 16.0;
    final plotH = h - padTop - padBottom;

    const maxVal = 100.0;
    const minVal = 0.0;

    // 超买超卖线
    final dashPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (final yRatio in [0.3, 0.7]) {
      final y = padTop + yRatio * plotH;
      canvas.drawLine(Offset(left, y), Offset(fullW - right, y), dashPaint);
    }

    final paint6 = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paint12 = Paint()
      ..color = Colors.orange
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paint24 = Paint()
      ..color = Colors.purple
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path6 = Path(), path12 = Path(), path24 = Path();
    bool first6 = true, first12 = true, first24 = true;

    for (var i = 0; i < len; i++) {
      final x = left + (len > 1 ? i / (len - 1) * plotW : plotW / 2);
      final r6y = padTop + ((maxVal - result.rsi6[i]) / (maxVal - minVal)) * plotH;
      final r12y = padTop + ((maxVal - result.rsi12[i]) / (maxVal - minVal)) * plotH;
      final r24y = padTop + ((maxVal - result.rsi24[i]) / (maxVal - minVal)) * plotH;

      if (first6) { path6.moveTo(x, r6y); first6 = false; } else { path6.lineTo(x, r6y); }
      if (first12) { path12.moveTo(x, r12y); first12 = false; } else { path12.lineTo(x, r12y); }
      if (first24) { path24.moveTo(x, r24y); first24 = false; } else { path24.lineTo(x, r24y); }
    }

    canvas.drawPath(path6, paint6);
    canvas.drawPath(path12, paint12);
    canvas.drawPath(path24, paint24);

    _drawLabel(canvas, 'RSI6', fullW - right - 2, padTop + 4, Colors.blue);
    _drawLabel(canvas, 'RSI12', fullW - right - 2, padTop + 18, Colors.orange);
    _drawLabel(canvas, 'RSI24', fullW - right - 2, padTop + 32, Colors.purple);
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width, y));
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter old) =>
      old.data != data || old.type != type;
}
