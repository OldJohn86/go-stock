import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/api/api_client.dart';
import 'package:go_stock_mobile/api/push_api.dart';

class _MockInterceptor extends Interceptor {
  Response? _nextResponse;

  void willReturn(int statusCode, dynamic data) {
    _nextResponse = Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: statusCode,
      data: data,
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_nextResponse != null) {
      handler.resolve(_nextResponse!);
    } else {
      handler.reject(DioException(
        requestOptions: options,
        message: 'no mock set',
      ));
    }
  }
}

void main() {
  late _MockInterceptor mock;
  late PushApi api;

  setUp(() {
    mock = _MockInterceptor();
    final dio = Dio()..interceptors.add(mock);
    final client = ApiClient.createWithDio(dio);
    api = PushApi.withClient(client);
  });

  group('registerToken', () {
    test('returns true on success', () async {
      mock.willReturn(200, {
        'code': 0,
        'message': 'success',
        'data': null,
      });

      final ok = await api.registerToken('abc123', 'ios');
      expect(ok, isTrue);
    });

    test('returns false on error', () async {
      mock.willReturn(200, {
        'code': -1,
        'message': 'token 无效',
        'data': null,
      });

      final ok = await api.registerToken('invalid', 'ios');
      expect(ok, isFalse);
    });
  });

  group('unregisterToken', () {
    test('returns true on success', () async {
      mock.willReturn(200, {
        'code': 0,
        'message': 'success',
        'data': null,
      });

      final ok = await api.unregisterToken('abc123');
      expect(ok, isTrue);
    });

    test('returns false on error', () async {
      mock.willReturn(200, {
        'code': -1,
        'message': 'token 不存在',
        'data': null,
      });

      final ok = await api.unregisterToken('nonexistent');
      expect(ok, isFalse);
    });
  });
}
