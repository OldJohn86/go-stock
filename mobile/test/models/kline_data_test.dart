import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/models/kline_data.dart';

void main() {
  group('KLineData', () {
    group('fromJson', () {
      test('parses complete JSON', () {
        final data = KLineData.fromJson({
          'day': '2024-01-02',
          'open': 10.0,
          'close': 10.5,
          'high': 10.8,
          'low': 9.9,
          'volume': 100000,
          'amount': 1050000,
          'changePercent': 5.0,
          'changeValue': 0.5,
          'amplitude': 8.0,
          'turnoverRate': 2.5,
          'ma': {'ma5': 10.2, 'ma10': 9.8},
        });

        expect(data.day, '2024-01-02');
        expect(data.open, 10.0);
        expect(data.close, 10.5);
        expect(data.high, 10.8);
        expect(data.low, 9.9);
        expect(data.volume, 100000);
        expect(data.amount, 1050000);
        expect(data.changePercent, 5.0);
        expect(data.changeValue, 0.5);
        expect(data.amplitude, 8.0);
        expect(data.turnoverRate, 2.5);
        expect(data.ma, {'ma5': 10.2, 'ma10': 9.8});
      });

      test('falls back to date field for day', () {
        final data = KLineData.fromJson({
          'date': '2024-06-15', 'open': 1, 'close': 2, 'high': 3, 'low': 1, 'volume': 100,
        });
        expect(data.day, '2024-06-15');
      });

      test('defaults for missing fields', () {
        final data = KLineData.fromJson({});
        expect(data.day, '');
        expect(data.open, 0.0);
        expect(data.close, 0.0);
        expect(data.volume, 0.0);
        expect(data.ma, isNull);
      });

      test('handles null ma', () {
        final data = KLineData.fromJson({
          'day': 'test', 'open': 1, 'close': 2, 'high': 3, 'low': 1, 'volume': 100, 'ma': null,
        });
        expect(data.ma, isNull);
      });

      test('handles string numeric values', () {
        final data = KLineData.fromJson({
          'day': '2024-01-02', 'open': '10.0', 'close': '10.5',
          'high': '10.8', 'low': '9.9', 'volume': '100000',
        });
        expect(data.open, 10.0);
        expect(data.close, 10.5);
        expect(data.high, 10.8);
        expect(data.low, 9.9);
        expect(data.volume, 100000);
      });

      test('handles string numeric edge cases', () {
        // empty string → 0 (fromJson default)
        final data = KLineData.fromJson({
          'day': '1', 'open': '', 'close': '', 'high': '', 'low': '', 'volume': '',
        });
        expect(data.open, 0.0);
        expect(data.close, 0.0);

        // whitespace string → 0
        final data2 = KLineData.fromJson({
          'day': '2', 'open': '  ', 'close': '100', 'high': '200', 'low': '50', 'volume': '5000',
        });
        expect(data2.open, 0.0); // trimmed empty → null → 0.0
        expect(data2.close, 100.0);
      });
    });

    group('isUp', () {
      test('returns true when close >= open', () {
        final up = KLineData.fromJson({
          'day': '1', 'open': 10, 'close': 10.5, 'high': 11, 'low': 9, 'volume': 100,
        });
        expect(up.isUp, isTrue);
      });

      test('returns true when close == open', () {
        final even = KLineData(day: '1', open: 10, close: 10, high: 11, low: 9, volume: 100);
        expect(even.isUp, isTrue);
      });

      test('returns false when close < open', () {
        final down = KLineData.fromJson({
          'day': '1', 'open': 10, 'close': 9.5, 'high': 11, 'low': 9, 'volume': 100,
        });
        expect(down.isUp, isFalse);
      });
    });
  });
}
