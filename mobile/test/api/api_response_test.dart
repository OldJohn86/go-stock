import 'package:flutter_test/flutter_test.dart';

import 'package:go_stock_mobile/api/api_client.dart';

void main() {
  group('ApiResponse', () {
    test('fromJson parses success response', () {
      final json = {
        'code': 0,
        'message': 'success',
        'data': {'key': 'value'},
      };
      final resp = ApiResponse.fromJson(json);
      expect(resp.code, 0);
      expect(resp.message, 'success');
      expect(resp.data, {'key': 'value'});
      expect(resp.isSuccess, isTrue);
    });

    test('fromJson parses error response', () {
      final json = {
        'code': -1,
        'message': '服务器错误',
        'data': null,
      };
      final resp = ApiResponse.fromJson(json);
      expect(resp.code, -1);
      expect(resp.message, '服务器错误');
      expect(resp.data, isNull);
      expect(resp.isSuccess, isFalse);
    });

    test('fromJson falls back to defaults for missing fields', () {
      final json = <String, dynamic>{};
      final resp = ApiResponse.fromJson(json);
      expect(resp.code, -1);
      expect(resp.message, '');
      expect(resp.data, isNull);
      expect(resp.isSuccess, isFalse);
    });

    test('toJson produces correct map', () {
      final resp = ApiResponse(
        code: 0,
        message: 'ok',
        data: [1, 2, 3],
      );
      final json = resp.toJson();
      expect(json['code'], 0);
      expect(json['message'], 'ok');
      expect(json['data'], [1, 2, 3]);
    });

    test('round-trip fromJson -> toJson preserves data', () {
      final original = {
        'code': 0,
        'message': 'success',
        'data': {'list': [1, 2, 3]},
      };
      final resp = ApiResponse.fromJson(original);
      expect(resp.toJson(), original);
    });
  });
}
