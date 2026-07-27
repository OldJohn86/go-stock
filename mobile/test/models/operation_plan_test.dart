import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/models/operation_plan.dart';

void main() {
  group('DailyOperationPlan', () {
    group('fromJson', () {
      test('parses complete JSON (camelCase)', () {
        final plan = DailyOperationPlan.fromJson({
          'id': 1,
          'planDate': '2026-07-26',
          'stockCode': '600519',
          'stockName': '贵州茅台',
          'overallJudgment': '震荡上行',
          'scenarios': '[]',
          'discipline': '严格执行止损',
          'summary': '今日计划',
          'riskWarning': '注意风险',
          'status': 'pending',
          'direction': 'buy',
          'plannedPrice': 1500.0,
          'plannedQuantity': 100,
          'reason': '看好后市',
          'remarks': '测试',
          'enableAlert': true,
          'notifyChannels': 'wechat',
        });

        expect(plan.id, 1);
        expect(plan.planDate, '2026-07-26');
        expect(plan.stockCode, '600519');
        expect(plan.stockName, '贵州茅台');
        expect(plan.overallJudgment, '震荡上行');
        expect(plan.status, 'pending');
        expect(plan.direction, 'buy');
        expect(plan.plannedPrice, 1500.0);
        expect(plan.plannedQuantity, 100);
        expect(plan.enableAlert, isTrue);
        expect(plan.notifyChannels, 'wechat');
      });

      test('parses complete JSON (PascalCase)', () {
        final plan = DailyOperationPlan.fromJson({
          'ID': 2,
          'PlanDate': '2026-07-27',
          'StockCode': '000001',
          'StockName': '平安银行',
          'Status': 'completed',
          'Direction': 'sell',
        });

        expect(plan.id, 2);
        expect(plan.planDate, '2026-07-27');
        expect(plan.stockCode, '000001');
        expect(plan.stockName, '平安银行');
        expect(plan.status, 'completed');
        expect(plan.direction, 'sell');
      });

      test('defaults for missing fields', () {
        final plan = DailyOperationPlan.fromJson({});
        expect(plan.id, 0);
        expect(plan.planDate, '');
        expect(plan.stockCode, '');
        expect(plan.stockName, '');
        expect(plan.status, 'pending');
        expect(plan.direction, 'buy');
        expect(plan.enableAlert, isFalse);
      });
    });

    group('statusLabel', () {
      test('returns correct labels', () {
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', status: 'pending').statusLabel, '待执行');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', status: 'executing').statusLabel, '执行中');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', status: 'completed').statusLabel, '已完成');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', status: 'expired').statusLabel, '已过期');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', status: 'unknown').statusLabel, 'unknown');
      });
    });

    group('directionLabel', () {
      test('returns correct labels', () {
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', direction: 'buy').directionLabel, '买入');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', direction: 'sell').directionLabel, '卖出');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', direction: 'hold').directionLabel, '持有');
        expect(DailyOperationPlan(planDate: '', stockCode: '', stockName: '', direction: 'other').directionLabel, 'other');
      });
    });

    group('scenarioList', () {
      test('parses JSON scenarios', () {
        final plan = DailyOperationPlan(
          planDate: '', stockCode: '', stockName: '',
          scenarios: '[{"title":"突破","condition":"price>1500","actionType":"buy","action":"买入","position":"50%","buyPriceRange":"1480-1520","stopLossPrice":"1450"}]',
        );
        final list = plan.scenarioList;
        expect(list.length, 1);
        expect(list[0].title, '突破');
        expect(list[0].actionType, 'buy');
        expect(list[0].buyPriceRange, '1480-1520');
        expect(list[0].stopLossPrice, '1450');
      });

      test('returns empty for empty scenarios', () {
        final plan = DailyOperationPlan(planDate: '', stockCode: '', stockName: '');
        expect(plan.scenarioList, isEmpty);
      });

      test('returns empty for invalid JSON', () {
        final plan = DailyOperationPlan(
          planDate: '', stockCode: '', stockName: '',
          scenarios: 'not-json',
        );
        expect(plan.scenarioList, isEmpty);
      });
    });

    group('toJson', () {
      test('round-trip preserves data', () {
        final original = DailyOperationPlan(
          id: 5,
          planDate: '2026-07-28',
          stockCode: '000333',
          stockName: '美的集团',
          overallJudgment: '看多',
          direction: 'buy',
          plannedPrice: 65.0,
          enableAlert: true,
        );
        final json = original.toJson();
        final restored = DailyOperationPlan.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.planDate, original.planDate);
        expect(restored.stockCode, original.stockCode);
        expect(restored.stockName, original.stockName);
        expect(restored.direction, original.direction);
        expect(restored.plannedPrice, original.plannedPrice);
        expect(restored.enableAlert, original.enableAlert);
      });
    });
  });

  group('OperationScenario', () {
    test('fromJson parses correctly', () {
      final s = OperationScenario.fromJson({
        'title': '回调买入',
        'condition': 'price<10',
        'actionType': 'buy',
        'action': '买入',
        'position': '30%',
        'buyPriceRange': '9.5-10',
        'stopLossPrice': '9.0',
      });
      expect(s.title, '回调买入');
      expect(s.condition, 'price<10');
      expect(s.actionType, 'buy');
      expect(s.position, '30%');
    });

    test('toJson round-trip', () {
      final s = OperationScenario(
        title: 'T', condition: 'C', actionType: 'buy',
        action: '买入', position: '50%', buyPriceRange: '10-11', stopLossPrice: '9.5',
      );
      final json = s.toJson();
      final restored = OperationScenario.fromJson(json);
      expect(restored.title, 'T');
      expect(restored.condition, 'C');
      expect(restored.actionType, 'buy');
    });
  });

  group('DailyOperationPlanPageData', () {
    test('fromJson parses correctly', () {
      final data = DailyOperationPlanPageData.fromJson({
        'list': [
          {'planDate': '2026-07-26', 'stockCode': '600519', 'stockName': '茅台'},
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
      final data = DailyOperationPlanPageData.fromJson({});
      expect(data.list, isEmpty);
      expect(data.total, 0);
      expect(data.page, 1);
      expect(data.pageSize, 20);
    });
  });
}
