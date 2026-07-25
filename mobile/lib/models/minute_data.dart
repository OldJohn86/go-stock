class MinuteData {
  final String time;
  final double price;
  final double volume;
  final double amount;

  MinuteData({
    required this.time,
    required this.price,
    required this.volume,
    this.amount = 0,
  });

  factory MinuteData.fromJson(Map<String, dynamic> json) {
    return MinuteData(
      time: json['time'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
