import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/models/minute_data.dart';

void main() {
  group('MinuteData.fromJson', () {
    test('parses complete JSON', () {
      final data = MinuteData.fromJson({
        'time': '09:35',
        'price': 15.6,
        'volume': 5000,
        'amount': 78000,
      });

      expect(data.time, '09:35');
      expect(data.price, 15.6);
      expect(data.volume, 5000);
      expect(data.amount, 78000);
    });

    test('defaults for missing fields', () {
      final data = MinuteData.fromJson({});
      expect(data.time, '');
      expect(data.price, 0.0);
      expect(data.volume, 0.0);
      expect(data.amount, 0.0);
    });

    test('handles null values', () {
      final data = MinuteData.fromJson({
        'time': null,
        'price': null,
        'volume': null,
        'amount': null,
      });
      expect(data.time, '');
      expect(data.price, 0.0);
      expect(data.volume, 0.0);
      expect(data.amount, 0.0);
    });
  });
}
