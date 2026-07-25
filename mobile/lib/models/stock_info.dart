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
}
