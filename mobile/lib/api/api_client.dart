import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ApiClient {
  late final Dio _dio;

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

  Future<ApiResponse> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final resp = await _dio.get(path, queryParameters: params);
      return ApiResponse.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        code: -1,
        message: _formatError(e),
      );
    }
  }

  Future<ApiResponse> post(String path, {dynamic data}) async {
    try {
      final resp = await _dio.post(path, data: data);
      return ApiResponse.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse(
        code: -1,
        message: _formatError(e),
      );
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
      onError?.call(e.toString());
    }
  }

  String _formatError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return '连接超时，请检查网络';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接到服务器 (${ApiConfig.baseUrl})';
    }
    return '网络请求失败: ${e.message}';
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
