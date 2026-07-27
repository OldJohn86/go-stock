import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/models/trading_record.dart';

void main() {
  group('TradingRecordItem', () {
    group('fromJson', () {
      test('parses complete JSON (PascalCase)', () {
        final item = TradingRecordItem.fromJson({
          'ID': 1,
          'StockCode': '600519',
          'StockName': '贵州茅台',
          'Direction': '买入',
          'Price': 1500.0,
          'Volume': 100,
          'Amount': 150000.0,
          'TradingTime': '2026-07-25 10:30:00',
          'Reason': '看好',
          'StopLossPrice': 1450.0,
          'TakeProfitPrice': 1600.0,
          'Fee': 30.0,
          'MarketValue': 150000.0,
          'Mindset': '谨慎乐观',
        });

        expect(item.id, 1);
        expect(item.stockCode, '600519');
        expect(item.stockName, '贵州茅台');
        expect(item.direction, '买入');
        expect(item.price, 1500.0);
        expect(item.volume, 100);
        expect(item.amount, 150000.0);
        expect(item.tradingTime, '2026-07-25 10:30:00');
        expect(item.reason, '看好');
        expect(item.stopLossPrice, 1450.0);
        expect(item.takeProfitPrice, 1600.0);
        expect(item.fee, 30.0);
        expect(item.marketValue, 150000.0);
        expect(item.mindset, '谨慎乐观');
      });

      test('parses JSON (camelCase)', () {
        final item = TradingRecordItem.fromJson({
          'id': 2,
          'stockCode': '000001',
          'stockName': '平安银行',
          'direction': '卖出',
          'price': 12.5,
          'volume': 200,
          'amount': 2500.0,
          'tradingTime': '2026-07-26 14:00:00',
          'closePrice': 12.5,
          'profitAmount': 100.0,
          'profitPercent': 4.0,
        });

        expect(item.id, 2);
        expect(item.stockCode, '000001');
        expect(item.direction, '卖出');
        expect(item.closePrice, 12.5);
        expect(item.profitAmount, 100.0);
        expect(item.profitPercent, 4.0);
      });

      test('defaults for missing fields', () {
        final item = TradingRecordItem.fromJson({});
        expect(item.id, 0);
        expect(item.stockCode, '');
        expect(item.stockName, '');
        expect(item.direction, '');
        expect(item.price, 0.0);
        expect(item.volume, 0);
        expect(item.amount, 0.0);
        expect(item.reason, isNull);
        expect(item.profitAmount, 0.0);
      });
    });

    group('isProfit', () {
      test('returns true when profitAmount > 0', () {
        final item = TradingRecordItem(
          id: 1, stockCode: '', stockName: '', direction: '买入',
          price: 10, volume: 100, amount: 1000, tradingTime: '',
          profitAmount: 50, profitPercent: 5,
        );
        expect(item.isProfit, isTrue);
      });

      test('returns false when profitAmount <= 0', () {
        final item = TradingRecordItem(
          id: 1, stockCode: '', stockName: '', direction: '买入',
          price: 10, volume: 100, amount: 1000, tradingTime: '',
          profitAmount: 0, profitPercent: 0,
        );
        expect(item.isProfit, isFalse);
      });
    });
  });

  group('TradingRecordStatistics', () {
    test('fromJson parses correctly', () {
      final stats = TradingRecordStatistics.fromJson({
        'totalBuyAmount': 500000,
        'totalSellAmount': 550000,
        'totalProfit': 50000,
        'profitRate': 10.0,
        'holdingsAmount': 300000,
        'currentValue': 320000,
        'stockCount': 5,
        'todayBuyAmount': 10000,
        'todaySellAmount': 20000,
        'todayRealizedProfit': 5000,
        'todayFloatingProfit': 3000,
        'todayProfit': 8000,
        'todayProfitRate': 2.5,
      });

      expect(stats.totalBuyAmount, 500000);
      expect(stats.totalSellAmount, 550000);
      expect(stats.totalProfit, 50000);
      expect(stats.profitRate, 10.0);
      expect(stats.holdingsAmount, 300000);
      expect(stats.currentValue, 320000);
      expect(stats.stockCount, 5);
      expect(stats.todayProfit, 8000);
      expect(stats.todayProfitRate, 2.5);
    });

    test('defaults for missing fields', () {
      final stats = TradingRecordStatistics.fromJson({});
      expect(stats.totalBuyAmount, 0.0);
      expect(stats.totalProfit, 0.0);
      expect(stats.stockCount, 0);
      expect(stats.todayProfit, 0.0);
    });
  });

  group('TradingRecordPageData', () {
    test('fromJson parses correctly', () {
      final data = TradingRecordPageData.fromJson({
        'list': [
          {'StockCode': '600519', 'StockName': '茅台', 'Direction': '买入', 'Price': 1500, 'Volume': 100, 'Amount': 150000, 'TradingTime': '2026-07-25'},
        ],
        'total': 1,
        'page': 1,
        'pageSize': 20,
        'totalPages': 1,
      });

      expect(data.list.length, 1);
      expect(data.total, 1);
      expect(data.page, 1);
      expect(data.pageSize, 20);
    });

    test('defaults for missing fields', () {
      final data = TradingRecordPageData.fromJson({});
      expect(data.list, isEmpty);
      expect(data.total, 0);
      expect(data.page, 1);
    });
  });
}
