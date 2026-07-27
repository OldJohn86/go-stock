/// 买卖五档数据
class OrderBookLevel {
  final double price;
  final double volume;

  const OrderBookLevel({required this.price, required this.volume});
}

class StockRealTime {
  final String stockCode;
  final String stockName;
  final double currentPrice;
  final double preClose;
  final double open;
  final double high;
  final double low;
  final String date;
  final String time;
  final double volume; // 成交的股票数（手）
  final double amount; // 成交金额（元）

  // 买卖五档
  final List<OrderBookLevel> buyLevels;
  final List<OrderBookLevel> sellLevels;

  StockRealTime({
    required this.stockCode,
    required this.stockName,
    required this.currentPrice,
    required this.preClose,
    required this.open,
    required this.high,
    required this.low,
    required this.date,
    required this.time,
    this.volume = 0,
    this.amount = 0,
    this.buyLevels = const [],
    this.sellLevels = const [],
  });

  factory StockRealTime.fromJson(Map<String, dynamic> json) {
    // 解析买卖五档
    final buyLevels = <OrderBookLevel>[];
    final sellLevels = <OrderBookLevel>[];
    for (int i = 1; i <= 5; i++) {
      final bp = (json['买$i报价'] as num?)?.toDouble();
      final bv = (json['买$i申报'] as num?)?.toDouble();
      if (bp != null && bp > 0) {
        buyLevels.add(OrderBookLevel(price: bp, volume: bv ?? 0));
      }
      final ap = (json['卖$i报价'] as num?)?.toDouble();
      final av = (json['卖$i申报'] as num?)?.toDouble();
      if (ap != null && ap > 0) {
        sellLevels.add(OrderBookLevel(price: ap, volume: av ?? 0));
      }
    }

    // 兼容 FollowedStock 没有 昨日收盘价 的情况，用 当前价格 - 价格变动 推算
    final parsedCurrentPrice = (json['当前价格'] as num?)?.toDouble() ?? 0.0;
    final rawPreClose = (json['昨日收盘价'] as num?)?.toDouble() ?? 0.0;
    final parsedPreClose = rawPreClose > 0
        ? rawPreClose
        : (parsedCurrentPrice - ((json['价格变动'] as num?)?.toDouble() ?? 0.0));

    return StockRealTime(
      stockCode: json['股票代码'] as String? ?? '',
      stockName: json['股票名称'] as String? ?? '',
      currentPrice: parsedCurrentPrice,
      preClose: parsedPreClose,
      open: (json['今日开盘价'] as num?)?.toDouble() ?? 0.0,
      high: (json['今日最高价'] as num?)?.toDouble() ?? 0.0,
      low: (json['今日最低价'] as num?)?.toDouble() ?? 0.0,
      date: json['日期'] as String? ?? '',
      time: json['时间'] as String? ?? '',
      volume: (json['成交的股票数'] as num?)?.toDouble() ?? 0,
      amount: (json['成交金额'] as num?)?.toDouble() ?? 0,
      buyLevels: buyLevels,
      sellLevels: sellLevels,
    );
  }

  double get change => preClose > 0 ? currentPrice - preClose : 0;
  double get changePercent =>
      preClose > 0 ? (change / preClose) * 100 : 0;

  bool get isUp => change >= 0;

  /// 换手率估算（成交额/市值没有，先返回 null）
  double? get turnoverRate => null;

  /// Serialize to a JSON map (mirrors [fromJson] keys).
  Map<String, dynamic> toJson() => {
        '股票代码': stockCode,
        '股票名称': stockName,
        '当前价格': currentPrice,
        '昨日收盘价': preClose,
        '今日开盘价': open,
        '今日最高价': high,
        '今日最低价': low,
        '日期': date,
        '时间': time,
        '成交的股票数': volume,
        '成交金额': amount,
      };

  /// 从股票代码和名称构造（用于快速导航，后续会拉取实时数据）
  factory StockRealTime.fromCode(String code, String name) {
    return StockRealTime(
      stockCode: code,
      stockName: name,
      currentPrice: 0,
      preClose: 0,
      open: 0,
      high: 0,
      low: 0,
      date: '',
      time: '',
    );
  }
}

/// 格式化成交量（手），万手显示
String formatVolume(double vol) {
  if (vol >= 10000) {
    return '${(vol / 10000).toStringAsFixed(2)}万手';
  }
  return '${vol.toStringAsFixed(0)}手';
}

/// 格式化金额（元），万/亿显示
String formatAmount(double amt) {
  if (amt >= 100000000) {
    return '${(amt / 100000000).toStringAsFixed(2)}亿';
  }
  if (amt >= 10000) {
    return '${(amt / 10000).toStringAsFixed(2)}万';
  }
  return '¥${amt.toStringAsFixed(2)}';
}
