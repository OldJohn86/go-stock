class KLineData {
  final String day;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;
  final double amount;
  final double changePercent;
  final double changeValue;
  final double amplitude;
  final double turnoverRate;
  final Map<String, double>? ma;

  KLineData({
    required this.day,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    this.amount = 0,
    this.changePercent = 0,
    this.changeValue = 0,
    this.amplitude = 0,
    this.turnoverRate = 0,
    this.ma,
  });

  factory KLineData.fromJson(Map<String, dynamic> json) {
    Map<String, double>? maMap;
    if (json['ma'] != null) {
      maMap = {};
      (json['ma'] as Map<String, dynamic>).forEach((k, v) {
        maMap![k] = _parseNum(v) ?? 0.0;
      });
    }

    return KLineData(
      day: json['day'] as String? ?? json['date'] as String? ?? '',
      open: _parseNum(json['open']) ?? 0.0,
      close: _parseNum(json['close']) ?? 0.0,
      high: _parseNum(json['high']) ?? 0.0,
      low: _parseNum(json['low']) ?? 0.0,
      volume: _parseNum(json['volume']) ?? 0.0,
      amount: _parseNum(json['amount']) ?? 0.0,
      changePercent: _parseNum(json['changePercent']) ?? 0.0,
      changeValue: _parseNum(json['changeValue']) ?? 0.0,
      amplitude: _parseNum(json['amplitude']) ?? 0.0,
      turnoverRate: _parseNum(json['turnoverRate']) ?? 0.0,
      ma: maMap,
    );
  }

  /// 安全解析数值字段（兼容number和string类型）
  static double? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// K线是阳线（收盘 >= 开盘）或平盘
  bool get isUp => close >= open;
}
