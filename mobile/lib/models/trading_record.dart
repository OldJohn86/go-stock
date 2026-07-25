/// 交易记录项
class TradingRecordItem {
  final int id;
  final String stockCode;
  final String stockName;
  final String direction; // 买入 / 卖出
  final double price;
  final int volume;
  final double amount;
  final String tradingTime;
  final String? reason;
  final double? stopLossPrice;
  final double? takeProfitPrice;
  final double? fee;
  final double? marketValue;
  final String? mindset;
  final double? recordedClosePrice;
  final double closePrice;
  final double profitAmount;
  final double profitPercent;

  TradingRecordItem({
    required this.id,
    required this.stockCode,
    required this.stockName,
    required this.direction,
    required this.price,
    required this.volume,
    required this.amount,
    required this.tradingTime,
    this.reason,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.fee,
    this.marketValue,
    this.mindset,
    this.recordedClosePrice,
    this.closePrice = 0,
    this.profitAmount = 0,
    this.profitPercent = 0,
  });

  factory TradingRecordItem.fromJson(Map<String, dynamic> json) {
    return TradingRecordItem(
      id: _parseInt(json['ID']) ?? _parseInt(json['id']) ?? 0,
      stockCode: json['StockCode'] as String? ?? json['stockCode'] as String? ?? '',
      stockName: json['StockName'] as String? ?? json['stockName'] as String? ?? '',
      direction: json['Direction'] as String? ?? json['direction'] as String? ?? '',
      price: _parseDouble(json['Price']) ?? _parseDouble(json['price']) ?? 0,
      volume: _parseInt(json['Volume']) ?? _parseInt(json['volume']) ?? 0,
      amount: _parseDouble(json['Amount']) ?? _parseDouble(json['amount']) ?? 0,
      tradingTime: json['TradingTime'] as String? ?? json['tradingTime'] as String? ?? '',
      reason: json['Reason'] as String? ?? json['reason'] as String?,
      stopLossPrice: _parseDouble(json['StopLossPrice']) ?? _parseDouble(json['stopLossPrice']),
      takeProfitPrice: _parseDouble(json['TakeProfitPrice']) ?? _parseDouble(json['takeProfitPrice']),
      fee: _parseDouble(json['Fee']) ?? _parseDouble(json['fee']),
      marketValue: _parseDouble(json['MarketValue']) ?? _parseDouble(json['marketValue']),
      mindset: json['Mindset'] as String? ?? json['mindset'] as String?,
      recordedClosePrice: _parseDouble(json['RecordedClosePrice']) ?? _parseDouble(json['recordedClosePrice']),
      closePrice: _parseDouble(json['closePrice']) ?? 0,
      profitAmount: _parseDouble(json['profitAmount']) ?? 0,
      profitPercent: _parseDouble(json['profitPercent']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// 是否盈利
  bool get isProfit => profitAmount > 0;
}

/// 交易统计数据
class TradingRecordStatistics {
  final double totalBuyAmount;
  final double totalSellAmount;
  final double totalProfit;
  final double profitRate;
  final double holdingsAmount;
  final double currentValue;
  final int stockCount;
  final double todayBuyAmount;
  final double todaySellAmount;
  final double todayRealizedProfit;
  final double todayFloatingProfit;
  final double todayProfit;
  final double todayProfitRate;

  TradingRecordStatistics({
    this.totalBuyAmount = 0,
    this.totalSellAmount = 0,
    this.totalProfit = 0,
    this.profitRate = 0,
    this.holdingsAmount = 0,
    this.currentValue = 0,
    this.stockCount = 0,
    this.todayBuyAmount = 0,
    this.todaySellAmount = 0,
    this.todayRealizedProfit = 0,
    this.todayFloatingProfit = 0,
    this.todayProfit = 0,
    this.todayProfitRate = 0,
  });

  factory TradingRecordStatistics.fromJson(Map<String, dynamic> json) {
    return TradingRecordStatistics(
      totalBuyAmount: _parseDouble(json['totalBuyAmount']) ?? 0,
      totalSellAmount: _parseDouble(json['totalSellAmount']) ?? 0,
      totalProfit: _parseDouble(json['totalProfit']) ?? 0,
      profitRate: _parseDouble(json['profitRate']) ?? 0,
      holdingsAmount: _parseDouble(json['holdingsAmount']) ?? 0,
      currentValue: _parseDouble(json['currentValue']) ?? 0,
      stockCount: _parseInt(json['stockCount']) ?? 0,
      todayBuyAmount: _parseDouble(json['todayBuyAmount']) ?? 0,
      todaySellAmount: _parseDouble(json['todaySellAmount']) ?? 0,
      todayRealizedProfit: _parseDouble(json['todayRealizedProfit']) ?? 0,
      todayFloatingProfit: _parseDouble(json['todayFloatingProfit']) ?? 0,
      todayProfit: _parseDouble(json['todayProfit']) ?? 0,
      todayProfitRate: _parseDouble(json['todayProfitRate']) ?? 0,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// 交易日志分页结果
class TradingRecordPageData {
  final List<TradingRecordItem> list;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  TradingRecordPageData({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TradingRecordPageData.fromJson(Map<String, dynamic> json) {
    final listJson = json['list'] as List<dynamic>? ?? [];
    return TradingRecordPageData(
      list: listJson.map((e) => TradingRecordItem.fromJson(e as Map<String, dynamic>)).toList(),
      total: _parseInt(json['total']) ?? 0,
      page: _parseInt(json['page']) ?? 1,
      pageSize: _parseInt(json['pageSize']) ?? 20,
      totalPages: _parseInt(json['totalPages']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
