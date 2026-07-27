import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/api/api_client.dart';

/// A mock interceptor that returns predefined responses based on path.
class MockInterceptor extends Interceptor {
  final Map<String, Response> _responses = {};
  final List<RequestOptions> capturedRequests = [];

  void onGet(String path, int statusCode, dynamic data) {
    _responses[path] = Response(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedRequests.add(options);
    final response = _responses[options.path];
    if (response != null) {
      handler.resolve(response);
    } else {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 404,
          data: {'code': -1, 'message': 'not mocked: ${options.path}'},
        ),
      );
    }
  }
}

void main() {
  late MockInterceptor mock;
  late Dio dio;
  late ApiClient client;

  setUp(() {
    mock = MockInterceptor();
    dio = Dio()..interceptors.add(mock);
    client = ApiClient.createWithDio(dio);
  });

  group('ApiClient.get()', () {
    test('returns parsed response on success', () async {
      mock.onGet('/test', 200, {
        'code': 0,
        'message': 'success',
        'data': {'foo': 'bar'},
      });

      final resp = await client.get('/test');
      expect(resp.isSuccess, isTrue);
      expect(resp.data, {'foo': 'bar'});
    });

    test('returns error response for non-zero code', () async {
      mock.onGet('/test', 200, {
        'code': -1,
        'message': '业务错误',
        'data': null,
      });

      final resp = await client.get('/test');
      expect(resp.isSuccess, isFalse);
      expect(resp.message, '业务错误');
    });

    test('passes query parameters', () async {
      mock.onGet('/search', 200, {
        'code': 0,
        'message': 'success',
        'data': [],
      });

      await client.get('/search', params: {'q': 'test', 'page': '1'});

      expect(mock.capturedRequests.length, 1);
      final req = mock.capturedRequests.first;
      expect(req.queryParameters['q'], 'test');
      expect(req.queryParameters['page'], '1');
    });
  });

  group('ApiClient.post()', () {
    test('sends and returns parsed response', () async {
      mock.onGet('/submit', 200, {
        'code': 0,
        'message': 'success',
        'data': {'id': 42},
      });

      // Override onGet expectation for post path
      mock.onGet('/submit', 200, {
        'code': 0,
        'message': 'success',
        'data': {'id': 42},
      });

      // For POST, we register a different path expectation
      // Create a Dio interceptor specifically for this
      final postMock = MockInterceptor();
      postMock.onGet('/submit', 200, {
        'code': 0,
        'message': 'success',
        'data': {'id': 42},
      });

      // Use a fresh Dio
      final postDio = Dio()..interceptors.add(postMock);
      final postClient = ApiClient.createWithDio(postDio);

      final resp = await postClient.post('/submit', data: {'name': 'test'});
      expect(resp.isSuccess, isTrue);
      expect(resp.data, {'id': 42});
    });
  });
}
