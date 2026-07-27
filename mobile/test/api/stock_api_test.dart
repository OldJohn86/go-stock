import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/api/api_client.dart';
import 'package:go_stock_mobile/api/stock_api.dart';

class _MockInterceptor extends Interceptor {
  final Map<String, Response> _responses = {};

  void onGet(String path, int statusCode, dynamic data,
      {Map<String, dynamic>? params}) {
    _responses[path] = Response(
      requestOptions: RequestOptions(path: path, queryParameters: params ?? {}),
      statusCode: statusCode,
      data: data,
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final response = _responses[options.path];
    if (response != null) {
      handler.resolve(response);
    } else {
      handler.reject(DioException(
        requestOptions: options,
        message: 'not mocked: ${options.path}',
      ));
    }
  }
}

void main() {
  late _MockInterceptor mock;
  late StockApi api;

  setUp(() {
    mock = _MockInterceptor();
    final dio = Dio()..interceptors.add(mock);
    final client = ApiClient.createWithDio(dio);
    api = StockApi.withClient(client);
  });

  group('getRealTimePrice', () {
    test('returns StockRealTime on success', () async {
      mock.onGet('/stock/real-time/000001', 200, {
        'code': 0,
        'message': 'success',
        'data': {
          '股票代码': '000001',
          '股票名称': '平安银行',
          '当前价格': 12.34,
        },
      });

      final result = await api.getRealTimePrice('000001');
      expect(result, isNotNull);
      expect(result!.stockCode, '000001');
      expect(result.stockName, '平安银行');
      expect(result.currentPrice, 12.34);
    });

    test('returns null on error', () async {
      mock.onGet('/stock/real-time/000001', 200, {
        'code': -1,
        'message': '找不到股票',
        'data': null,
      });

      final result = await api.getRealTimePrice('000001');
      expect(result, isNull);
    });

    test('returns null when data is null', () async {
      mock.onGet('/stock/real-time/000001', 200, {
        'code': 0,
        'message': 'success',
        'data': null,
      });

      final result = await api.getRealTimePrice('000001');
      expect(result, isNull);
    });
  });

  group('getFollowList', () {
    test('returns stock list on success', () async {
      mock.onGet('/follow/list', 200, {
        'code': 0,
        'message': 'success',
        'data': [
          {'股票代码': '600519', '股票名称': '贵州茅台', '当前价格': 1888.0},
          {'股票代码': '000858', '股票名称': '五粮液', '当前价格': 168.0},
        ],
      });

      final list = await api.getFollowList();
      expect(list.length, 2);
      expect(list[0].stockCode, '600519');
      expect(list[1].stockName, '五粮液');
    });

    test('returns empty list on error', () async {
      mock.onGet('/follow/list', 200, {
        'code': -1,
        'message': 'token 无效',
        'data': null,
      });

      final list = await api.getFollowList();
      expect(list, isEmpty);
    });
  });

  group('getKLineData', () {
    test('returns kline list on success', () async {
      mock.onGet('/stock/000001/kline', 200, {
        'code': 0,
        'message': 'success',
        'data': [
          {
            'date': '2024-01-02',
            'open': 10.0,
            'close': 10.5,
            'high': 10.8,
            'low': 9.9,
            'volume': 100000,
          },
        ],
      });

      final list = await api.getKLineData('000001');
      expect(list.length, 1);
      expect(list[0].close, 10.5);
    });

    test('returns empty list on error', () async {
      mock.onGet('/stock/000001/kline', 200, {
        'code': -1,
        'message': 'fail',
        'data': null,
      });

      final list = await api.getKLineData('000001');
      expect(list, isEmpty);
    });
  });

  group('Group operations', () {
    test('getGroupList returns list of maps', () async {
      mock.onGet('/group/list', 200, {
        'code': 0,
        'message': 'success',
        'data': [
          {'id': 1, 'name': '自选'},
          {'id': 2, 'name': 'ETF'},
        ],
      });

      final list = await api.getGroupList();
      expect(list.length, 2);
      expect(list[0]['name'], '自选');
    });

    test('createGroup returns true on success', () async {
      mock.onGet('/group/create', 200, {
        'code': 0,
        'message': 'success',
        'data': null,
      });

      final ok = await api.createGroup(name: '测试分组');
      expect(ok, isTrue);
    });

    test('deleteGroup returns true on success', () async {
      mock.onGet('/group/delete/1', 200, {
        'code': 0,
        'message': 'success',
        'data': null,
      });

      final ok = await api.deleteGroup(1);
      expect(ok, isTrue);
    });

    test('getGroupStockCodes returns codes list', () async {
      mock.onGet('/group/stocks', 200, {
        'code': 0,
        'message': 'success',
        'data': [
          {'stockCode': '000001'},
          {'stockCode': '600519'},
        ],
      });

      final codes = await api.getGroupStockCodes(1);
      expect(codes, ['000001', '600519']);
    });
  });

  group('Index operations', () {
    test('getIndexList returns stock list', () async {
      mock.onGet('/index/list', 200, {
        'code': 0,
        'message': 'success',
        'data': [
          {'股票代码': '000001', '股票名称': '上证指数', '当前价格': 3200.0},
        ],
      });

      final list = await api.getIndexList();
      expect(list.length, 1);
      expect(list[0].stockCode, '000001');
      expect(list[0].stockName, '上证指数');
    });
  });
}
