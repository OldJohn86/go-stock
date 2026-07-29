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

  // 涨跌幅（优先用后端直接返回的涨跌幅，避免 DB 字段计算为 0%）
  final double changePercent;

  // 买卖五档
  final List<OrderBookLevel> buyLevels;
  final List<OrderBookLevel> sellLevels;

  StockRealTime({
    required this.stockCode,
    required this.stockName,
    required this.currentPrice,
    required this.preClose,
    this.changePercent = 0,
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
    // 安全解析数值（后端有时返回字符串如"3805.46"，有时返回数字）
    double v(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // 解析买卖五档（后端使用中文数字键名如"买一报价"，详见 stock_data_api.go）
    const chineseNums = ['', '一', '二', '三', '四', '五'];
    final buyLevels = <OrderBookLevel>[];
    final sellLevels = <OrderBookLevel>[];
    for (int i = 1; i <= 5; i++) {
      final key = chineseNums[i];
      final bp = v(json['买$key报价']);
      final bv = v(json['买$key申报']);
      if (bp > 0) {
        buyLevels.add(OrderBookLevel(price: bp, volume: bv));
      }
      final ap = v(json['卖$key报价']);
      final av = v(json['卖$key申报']);
      if (ap > 0) {
        sellLevels.add(OrderBookLevel(price: ap, volume: av));
      }
    }

    // 兼容 FollowedStock 没有 昨日收盘价 的情况，用 当前价格 - 价格变动 推算
    final parsedCurrentPrice = v(json['当前价格']);
    final rawPreClose = v(json['昨日收盘价']);
    final parsedPreClose = rawPreClose > 0
        ? rawPreClose
        : (parsedCurrentPrice - v(json['价格变动']));

    // 优先用后端直返涨跌幅，不存在时用价格推算
    final parsedChangePercent = json.containsKey('涨跌幅')
        ? v(json['涨跌幅'])
        : parsedPreClose > 0
            ? ((parsedCurrentPrice - parsedPreClose) / parsedPreClose) * 100
            : 0.0;

    return StockRealTime(
      stockCode: json['股票代码'] as String? ?? '',
      stockName: json['股票名称'] as String? ?? '',
      currentPrice: parsedCurrentPrice,
      preClose: parsedPreClose,
      changePercent: parsedChangePercent,
      open: v(json['今日开盘价']),
      high: v(json['今日最高价']),
      low: v(json['今日最低价']),
      date: json['日期'] as String? ?? '',
      time: json['时间'] as String? ?? '',
      volume: v(json['成交的股票数']),
      amount: v(json['成交金额']),
      buyLevels: buyLevels,
      sellLevels: sellLevels,
    );
  }

  double get change => preClose > 0 ? currentPrice - preClose : 0;

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
