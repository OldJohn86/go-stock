import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../utils/cache_manager.dart';

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

  /// Whether response caching is enabled.
  bool cacheEnabled = true;

  /// Build a deterministic cache key from the request path and query params.
  static String _buildCacheKey(String path, Map<String, dynamic>? params) {
    final buffer = StringBuffer(path);
    if (params != null && params.isNotEmpty) {
      final sortedKeys = params.keys.toList()..sort();
      for (final key in sortedKeys) {
        final value = params[key];
        if (value is List) {
          buffer.write('|$key=${value.join(',')}');
        } else {
          buffer.write('|$key=$value');
        }
      }
    }
    return buffer.toString();
  }

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

  /// Same as [get] but caches the response in SharedPreferences.
  ///
  /// On a cache hit within [maxAge], returns the cached response without a
  /// network call. On a cache miss or expiry, fetches from the network and
  /// caches the result. On network failure, optionally falls back to stale
  /// (expired) cache when [useStaleOnError] is true.
  Future<ApiResponse> getCached(
    String path, {
    Map<String, dynamic>? params,
    Duration maxAge = CacheManager.realtimeMaxAge,
    bool useStaleOnError = true,
  }) async {
    if (!cacheEnabled) {
      return get(path, params: params);
    }

    final cacheKey = _buildCacheKey(path, params);

    // Try cache first
    final cached = await CacheManager.get<String>(
      cacheKey,
      (map) => map['d'] as String,
      maxAge: maxAge,
    );
    if (cached != null) {
      try {
        return ApiResponse.fromJson(
          json.decode(cached) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupted cache entry, fall through to network
      }
    }

    // Cache miss / expired, fetch from network
    final result = await _requestWithRetry(
      () => _dio.get(path, queryParameters: params),
    );

    if (result.isSuccess) {
      await _saveCache(cacheKey, result);
      return result;
    }

    // Network error — try stale cache as fallback
    if (useStaleOnError) {
      final stale = await CacheManager.getStale<String>(
        cacheKey,
        (map) => map['d'] as String,
      );
      if (stale != null) {
        return ApiResponse.fromJson(
          json.decode(stale) as Map<String, dynamic>,
        );
      }
    }

    return result;
  }

  /// Returns cached data immediately if available, then fetches fresh data from
  /// the network in the background and updates the cache.
  ///
  /// - When a fresh cache exists within [maxAge]: returns the cached response
  ///   and schedules a background refresh.
  /// - When cache is stale or missing: returns the result of [get] (which
  ///   fetches from network).
  /// - When the network request fails and [useStaleOnError] is true: returns
  ///   stale (expired) cache as a fallback.
  ///
  /// Use this in UI pages so the user sees data immediately while fresh data
  /// loads silently.
  Future<ApiResponse> getWithCache(
    String path, {
    Map<String, dynamic>? params,
    required Duration maxAge,
    bool useStaleOnError = true,
  }) async {
    if (!cacheEnabled) {
      return get(path, params: params);
    }

    final cacheKey = _buildCacheKey(path, params);

    // Try cache first
    final cached = await CacheManager.get<String>(
      cacheKey,
      (map) => map['d'] as String,
      maxAge: maxAge,
    );
    if (cached != null) {
      // Return cached immediately, refresh in background
      _refreshCacheInBackground(path, params, cacheKey);
      try {
        return ApiResponse.fromJson(
          json.decode(cached) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupted cache, ignore and fall through
      }
    }

    // Cache miss or corrupted, fetch from network
    final result = await _requestWithRetry(
      () => _dio.get(path, queryParameters: params),
    );

    if (result.isSuccess) {
      await _saveCache(cacheKey, result);
      return result;
    }

    // Network error with stale fallback
    if (useStaleOnError) {
      final stale = await CacheManager.getStale<String>(
        cacheKey,
        (map) => map['d'] as String,
      );
      if (stale != null) {
        return ApiResponse.fromJson(
          json.decode(stale) as Map<String, dynamic>,
        );
      }
    }

    return result;
  }

  /// Remove the cached response for a specific endpoint.
  Future<void> clearCache(String path, {Map<String, dynamic>? params}) async {
    if (!cacheEnabled) return;
    await CacheManager.remove(_buildCacheKey(path, params));
  }

  /// Persist an [ApiResponse] into the cache.
  Future<void> _saveCache(String cacheKey, ApiResponse response) async {
    await CacheManager.set<String>(
      cacheKey,
      json.encode(response.toJson()),
      (s) => {'d': s},
    );
  }

  /// Fire-and-forget background cache refresh.
  void _refreshCacheInBackground(
    String path,
    Map<String, dynamic>? params,
    String cacheKey,
  ) {
    _requestWithRetry(() => _dio.get(path, queryParameters: params))
        .then((result) {
      if (result.isSuccess) {
        _saveCache(cacheKey, result);
      }
    }).catchError((_) {
      // Silently ignore background refresh failures
    });
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

  /// Serialize to a JSON map (mirrors [fromJson] keys).
  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'data': data,
      };

  bool get isSuccess => code == 0;
}
