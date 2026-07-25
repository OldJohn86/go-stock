import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// Callback for network state changes.
///
/// `success` is true when the request completes without a connectivity/timeout
/// error. `errorMessage` is set only when the request ultimately fails.
typedef NetworkStateCallback = void Function({
  required bool success,
  String? errorMessage,
});

class ApiClient {
  late final Dio _dio;

  /// Maximum number of retries for connection/timeout errors.
  static const int _maxRetries = 2;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.apiV1,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => debugPrint('[API] $o'),
    ));
  }

  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  // ---------------------------------------------------------------------------
  // Network state callback registry
  // ---------------------------------------------------------------------------

  static final List<NetworkStateCallback> _networkCallbacks = [];

  /// Register a callback that fires after every API request.
  ///
  /// The callback receives `success=true` when the request completes without a
  /// connectivity/timeout error (even if the HTTP status is non-2xx), and
  /// `success=false` with an error message when the request could not reach the
  /// server or timed out after all retries.
  static void addNetworkCallback(NetworkStateCallback callback) {
    _networkCallbacks.add(callback);
  }

  static void _notifyNetworkState({
    required bool success,
    String? errorMessage,
  }) {
    for (final cb in _networkCallbacks) {
      cb(success: success, errorMessage: errorMessage);
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP methods with retry + exponential backoff
  // ---------------------------------------------------------------------------

  Future<ApiResponse> get(String path, {Map<String, dynamic>? params}) async {
    return _requestWithRetry(() => _dio.get(path, queryParameters: params));
  }

  Future<ApiResponse> post(String path, {dynamic data}) async {
    return _requestWithRetry(() => _dio.post(path, data: data));
  }

  /// Executes [request], retrying up to [_maxRetries] times with exponential
  /// backoff when the error is a connection timeout, receive timeout, or
  /// generic connection error.
  Future<ApiResponse> _requestWithRetry(
    Future<Response> Function() request, {
    int retryCount = 0,
  }) async {
    try {
      final resp = await request();
      _notifyNetworkState(success: true);
      return ApiResponse.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (_isRetryable(e) && retryCount < _maxRetries) {
        // Exponential backoff: 1s, 2s
        final delay = Duration(seconds: 1 << retryCount);
        debugPrint('[API] Retry #${retryCount + 1} after ${delay.inSeconds}s '
            '(${e.type.name})');
        await Future.delayed(delay);
        return _requestWithRetry(request, retryCount: retryCount + 1);
      }
      final errorMsg = _formatError(e);
      _notifyNetworkState(success: false, errorMessage: errorMsg);
      return ApiResponse(code: -1, message: errorMsg);
    }
  }

  /// Returns true when the [DioException] is related to connectivity or
  /// timeouts — errors worth retrying.
  bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// SSE 流式请求，逐行回调
  Future<void> getSSE(
    String path, {
    Map<String, dynamic>? params,
    required void Function(String event, String data) onMessage,
    VoidCallback? onDone,
    void Function(String error)? onError,
  }) async {
    try {
      final resp = await _dio.get(
        path,
        queryParameters: params,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = resp.data as ResponseBody;
      final lines = stream.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter());

      String currentEvent = '';
      await for (final line in lines) {
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7);
        } else if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            onDone?.call();
            return;
          }
          onMessage(currentEvent, data);
        }
      }
      onDone?.call();
    } catch (e) {
      final errorMsg = _formatSSEError(e);
      _notifyNetworkState(success: false, errorMessage: errorMsg);
      onError?.call(errorMsg);
    }
  }

  String _formatSSEError(Object e) {
    if (e is DioException) {
      return _formatError(e);
    }
    return '网络请求失败: $e';
  }

  /// Categorizes [DioException] into user-friendly Chinese error messages.
  String _formatError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.connectionError:
        return '网络不可用，请检查网络连接';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return '认证失败，请重新登录';
        }
        if (statusCode != null && statusCode >= 500) {
          return '服务器错误 ($statusCode)，请稍后重试';
        }
        if (statusCode != null && statusCode >= 400) {
          return '请求错误 ($statusCode)';
        }
        return '服务器响应异常';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '安全证书验证失败';
      default:
        return '网络请求失败: ${e.message ?? "未知错误"}';
    }
  }
}

class ApiResponse {
  final int code;
  final String message;
  final dynamic data;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: json['data'],
    );
  }

  bool get isSuccess => code == 0;
}
