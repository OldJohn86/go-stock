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
  });

  factory StockRealTime.fromJson(Map<String, dynamic> json) {
    return StockRealTime(
      stockCode: json['股票代码'] as String? ?? '',
      stockName: json['股票名称'] as String? ?? '',
      currentPrice: (json['当前价格'] as num?)?.toDouble() ?? 0.0,
      preClose: (json['昨日收盘价'] as num?)?.toDouble() ?? 0.0,
      open: (json['今日开盘价'] as num?)?.toDouble() ?? 0.0,
      high: (json['今日最高价'] as num?)?.toDouble() ?? 0.0,
      low: (json['今日最低价'] as num?)?.toDouble() ?? 0.0,
      date: json['日期'] as String? ?? '',
      time: json['时间'] as String? ?? '',
    );
  }

  double get change => preClose > 0 ? currentPrice - preClose : 0;
  double get changePercent =>
      preClose > 0 ? (change / preClose) * 100 : 0;

  bool get isUp => change >= 0;

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
