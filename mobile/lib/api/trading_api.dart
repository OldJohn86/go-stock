import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/trading_record.dart';
import 'api_client.dart';

/// 交易日志 API
class TradingApi {
  final _client = ApiClient();

  /// 获取交易日志列表
  Future<TradingRecordPageData?> getRecords({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? direction,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (direction != null && direction.isNotEmpty) params['direction'] = direction;
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

    final resp = await _client.get('/trading/records', params: params);
    if (resp.isSuccess && resp.data != null) {
      return TradingRecordPageData.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 获取每日盈亏数据（交易日历热力图用）
  Future<List<Map<String, dynamic>>> getDailyPnL({int? year, int? month}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    final resp = await _client.get('/trading/daily-pnl', params: params);
    if (resp.isSuccess && resp.data != null) {
      final list = resp.data as List<dynamic>?;
      if (list != null) return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 获取交易统计数据
  Future<TradingRecordStatistics?> getStatistics() async {
    final resp = await _client.get('/trading/statistics');
    if (resp.isSuccess && resp.data != null) {
      return TradingRecordStatistics.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 新增/更新交易记录
  /// [record] 的 id=0 表示新增，id>0 表示更新
  Future<bool> saveRecord({
    int id = 0,
    required String stockCode,
    required String stockName,
    required String direction,
    required double price,
    required int volume,
    double fee = 0,
    double stopLossPrice = 0,
    double takeProfitPrice = 0,
    String? reason,
    String? mindset,
    String? tradingTime,
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'stockCode': stockCode,
      'stockName': stockName,
      'direction': direction,
      'price': price,
      'volume': volume,
      'fee': fee,
      'stopLossPrice': stopLossPrice,
      'takeProfitPrice': takeProfitPrice,
    };
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    if (mindset != null && mindset.isNotEmpty) body['mindset'] = mindset;
    if (tradingTime != null && tradingTime.isNotEmpty) body['tradingTime'] = tradingTime;

    final resp = await _client.post('/trading/save', data: body);
    return resp.isSuccess;
  }

  /// 删除交易记录
  Future<bool> deleteRecord(int id) async {
    final resp = await _client.post('/trading/delete/$id');
    return resp.isSuccess;
  }

  /// 导出交易记录为 CSV 文件
  /// 返回下载文件的路径，失败返回 null
  Future<String?> exportRecords({
    String? keyword,
    String? direction,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (direction != null && direction.isNotEmpty) params['direction'] = direction;
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;

    try {
      // Use Dio directly to download raw CSV (not JSON response)
      final dio = Dio(BaseOptions(
        baseUrl: _client.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.get('/trading/export', queryParameters: params);
      if (response.statusCode == 200 && response.data is List<int>) {
        final dir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/trading_records_$timestamp.csv');
        await file.writeAsBytes(response.data as List<int>);
        return file.path;
      }
    } catch (e) {
      // Failed to download
    }
    return null;
  }
}
