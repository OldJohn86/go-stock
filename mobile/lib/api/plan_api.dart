import 'dart:convert';

import '../models/operation_plan.dart';
import 'api_client.dart';

/// 每日操作计划 API
class PlanApi {
  final _client = ApiClient();

  /// 获取操作计划列表
  Future<DailyOperationPlanPageData?> getList({
    int page = 1,
    int pageSize = 20,
    String? stockCode,
    String? stockName,
    String? planDate,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
    };
    if (stockCode != null && stockCode.isNotEmpty) params['stockCode'] = stockCode;
    if (stockName != null && stockName.isNotEmpty) params['stockName'] = stockName;
    if (planDate != null && planDate.isNotEmpty) params['planDate'] = planDate;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final resp = await _client.get('/operation-plan/list', params: params);
    if (resp.isSuccess && resp.data != null) {
      return DailyOperationPlanPageData.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 获取单个操作计划详情
  Future<DailyOperationPlan?> getById(int id) async {
    final resp = await _client.get('/operation-plan/$id');
    if (resp.isSuccess && resp.data != null) {
      return DailyOperationPlan.fromJson(resp.data as Map<String, dynamic>);
    }
    return null;
  }

  /// 保存操作计划（新增或更新）
  Future<bool> save(DailyOperationPlan plan) async {
    final data = plan.toJson();
    // scenarios 和 discipline 是 JSON 字符串，需要确保它们是字符串格式
    if (data['scenarios'] is List) {
      data['scenarios'] = jsonEncode(data['scenarios']);
    }
    if (data['discipline'] is List) {
      data['discipline'] = jsonEncode(data['discipline']);
    }
    final resp = await _client.post('/operation-plan/save', data: data);
    return resp.isSuccess;
  }

  /// 删除操作计划
  Future<bool> delete(int id) async {
    final resp = await _client.post('/operation-plan/delete/$id');
    return resp.isSuccess;
  }

  /// 更新状态
  Future<bool> updateStatus(int id, String status) async {
    final resp = await _client.post('/operation-plan/status', data: {
      'id': id,
      'status': status,
    });
    return resp.isSuccess;
  }
}
