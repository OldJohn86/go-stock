import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// 推送通知 API
class PushApi {
  late final ApiClient _client;

  PushApi() : _client = ApiClient();

  @visibleForTesting
  PushApi.withClient(this._client);

  /// 注册设备推送 Token
  Future<bool> registerToken(String token, String platform) async {
    final resp = await _client.post('/push/register-token', data: {
      'token': token,
      'platform': platform,
    });
    return resp.isSuccess;
  }

  /// 注销设备推送 Token
  Future<bool> unregisterToken(String token) async {
    final resp = await _client.post('/push/unregister-token', data: {
      'token': token,
    });
    return resp.isSuccess;
  }
}
