import 'dart:math';

import '../models/kline_data.dart';

/// 技术指标计算结果基类
class IndicatorResult {
  final String name;
  IndicatorResult({required this.name});
}

/// MACD 指标
class MacdResult extends IndicatorResult {
  final List<double> dif;
  final List<double> dea;
  final List<double> histogram; // MACD柱 = 2*(DIF-DEA)

  MacdResult({
    required this.dif,
    required this.dea,
    required this.histogram,
  }) : super(name: 'MACD');
}

/// KDJ 指标
class KdjResult extends IndicatorResult {
  final List<double> k;
  final List<double> d;
  final List<double> j;

  KdjResult({
    required this.k,
    required this.d,
    required this.j,
  }) : super(name: 'KDJ');
}

/// RSI 指标
class RsiResult extends IndicatorResult {
  final List<double> rsi6;
  final List<double> rsi12;
  final List<double> rsi24;

  RsiResult({
    required this.rsi6,
    required this.rsi12,
    required this.rsi24,
  }) : super(name: 'RSI');
}

/// K线技术指标计算工具
class KlineIndicators {
  /// 计算 MACD
  /// [fast] = 12, [slow] = 26, [signal] = 9
  static MacdResult macd(List<KLineData> data,
      {int fast = 12, int slow = 26, int signal = 9}) {
    final closes = data.map((d) => d.close).toList();
    final len = closes.length;

    final dif = <double>[];
    final dea = <double>[];
    final histogram = <double>[];

    if (len < slow) {
      // 数据不足，返回空
      for (var i = 0; i < len; i++) {
        dif.add(0);
        dea.add(0);
        histogram.add(0);
      }
      return MacdResult(dif: dif, dea: dea, histogram: histogram);
    }

    // 计算 EMA
    double ema12 = _ema(closes, fast);
    double ema26 = _ema(closes, slow);

    for (var i = 0; i < len; i++) {
      if (i < slow - 1) {
        dif.add(0);
        dea.add(0);
        histogram.add(0);
        continue;
      }

      if (i == slow - 1) {
        // 首个 EMA 值 = 简单平均
        ema12 = _sma(closes, i, fast);
        ema26 = _sma(closes, i, slow);
      } else {
        ema12 = _nextEma(closes[i], ema12, fast);
        ema26 = _nextEma(closes[i], ema26, slow);
      }

      final d = ema12 - ema26;
      dif.add(d);

      if (i == slow - 1 + signal - 1 || (i == slow - 1 && i == 0)) {
        dea.add(d > 0 ? d : -d); // 初始近似
      } else if (i > slow - 1) {
        final prevDea = dea.length > 1 ? dea.last : dea.isEmpty ? d : dea[0];
        final deaVal = _nextEma(d, prevDea, signal);
        dea.add(deaVal);
      } else {
        dea.add(0);
      }

      // MACD柱
      final h = 2 * (dif.last - dea.last);
      histogram.add(h);
    }

    return MacdResult(dif: dif, dea: dea, histogram: histogram);
  }

  /// 计算 KDJ (9,3,3)
  static KdjResult kdj(List<KLineData> data, {int n = 9, int k1 = 3, int d1 = 3}) {
    final len = data.length;
    final k = <double>[];
    final d = <double>[];
    final j = <double>[];

    if (len < n) {
      for (var i = 0; i < len; i++) {
        k.add(50);
        d.add(50);
        j.add(50);
      }
      return KdjResult(k: k, d: d, j: j);
    }

    double prevK = 50;
    double prevD = 50;

    for (var i = 0; i < len; i++) {
      double rsv;
      if (i < n - 1) {
        rsv = 50;
      } else {
        double low9 = double.infinity;
        double high9 = double.negativeInfinity;
        for (var jj = i - n + 1; jj <= i; jj++) {
          low9 = min(low9, data[jj].low);
          high9 = max(high9, data[jj].high);
        }
        if (high9 == low9) {
          rsv = 50;
        } else {
          rsv = ((data[i].close - low9) / (high9 - low9)) * 100;
        }
      }

      final ki = (2.0 / 3) * prevK + (1.0 / 3) * rsv;
      final di = (2.0 / 3) * prevD + (1.0 / 3) * ki;
      final ji = 3 * ki - 2 * di;

      k.add(ki);
      d.add(di);
      j.add(ji);

      prevK = ki;
      prevD = di;
    }

    return KdjResult(k: k, d: d, j: j);
  }

  /// 计算 RSI
  static RsiResult rsi(List<KLineData> data) {
    final closes = data.map((d) => d.close).toList();
    final len = closes.length;

    final rsi6 = <double>[];
    final rsi12 = <double>[];
    final rsi24 = <double>[];

    if (len < 2) {
      for (var i = 0; i < len; i++) {
        rsi6.add(50);
        rsi12.add(50);
        rsi24.add(50);
      }
      return RsiResult(rsi6: rsi6, rsi12: rsi12, rsi24: rsi24);
    }

    rsi6.addAll(_calcRsi(closes, 6));
    rsi12.addAll(_calcRsi(closes, 12));
    rsi24.addAll(_calcRsi(closes, 24));

    return RsiResult(rsi6: rsi6, rsi12: rsi12, rsi24: rsi24);
  }

  // ---- 辅助方法 ----

  static List<double> _calcRsi(List<double> closes, int period) {
    final len = closes.length;
    final result = <double>[];
    if (len < period + 1) {
      for (var i = 0; i < len; i++) {
        result.add(50);
      }
      return result;
    }

    double avgGain = 0, avgLoss = 0;
    for (var i = 1; i <= period; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff > 0) {
        avgGain += diff;
      } else {
        avgLoss -= diff;
      }
    }
    avgGain /= period;
    avgLoss /= period;

    result.addAll(List.filled(period + 1, 50));

    for (var i = period + 1; i < len; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff > 0) {
        avgGain = (avgGain * (period - 1) + diff) / period;
        avgLoss = (avgLoss * (period - 1)) / period;
      } else {
        avgGain = (avgGain * (period - 1)) / period;
        avgLoss = (avgLoss * (period - 1) - diff) / period;
      }

      final rs = avgLoss == 0 ? 100 : avgGain / avgLoss;
      result.add(100 - 100 / (1 + rs));
    }

    return result;
  }

  static double _sma(List<double> values, int end, int period) {
    double sum = 0;
    final start = end - period + 1;
    for (var i = start; i <= end; i++) {
      sum += values[i];
    }
    return sum / period;
  }

  static double _ema(List<double> values, int period) {
    final len = values.length;
    if (len < period) return values.last;
    double sum = 0;
    for (var i = len - period; i < len; i++) {
      sum += values[i];
    }
    final sma = sum / period;
    double ema = sma;
    final multiplier = 2.0 / (period + 1);
    for (var i = len - period + 1; i < len; i++) {
      ema = (values[i] - ema) * multiplier + ema;
    }
    return ema;
  }

  static double _nextEma(double price, double prevEma, int period) {
    final multiplier = 2.0 / (period + 1);
    return (price - prevEma) * multiplier + prevEma;
  }
}
