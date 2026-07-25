import 'dart:convert';

/// 操作情景方案
class OperationScenario {
  final String title;
  final String condition;
  final String actionType;
  final String action;
  final String position;
  final String buyPriceRange;
  final String stopLossPrice;

  OperationScenario({
    required this.title,
    required this.condition,
    required this.actionType,
    required this.action,
    required this.position,
    required this.buyPriceRange,
    required this.stopLossPrice,
  });

  factory OperationScenario.fromJson(Map<String, dynamic> json) {
    return OperationScenario(
      title: json['title'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      action: json['action'] as String? ?? '',
      position: json['position'] as String? ?? '',
      buyPriceRange: json['buyPriceRange'] as String? ?? '',
      stopLossPrice: json['stopLossPrice'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'condition': condition,
        'actionType': actionType,
        'action': action,
        'position': position,
        'buyPriceRange': buyPriceRange,
        'stopLossPrice': stopLossPrice,
      };
}

/// 每日操作计划
class DailyOperationPlan {
  final int id;
  final String planDate;
  final String stockCode;
  final String stockName;
  final String overallJudgment;
  final String scenarios;
  final String discipline;
  final String summary;
  final String riskWarning;
  final String status;
  final String remarks;
  final bool enableAlert;
  final String notifyChannels;

  DailyOperationPlan({
    this.id = 0,
    required this.planDate,
    required this.stockCode,
    required this.stockName,
    this.overallJudgment = '',
    this.scenarios = '',
    this.discipline = '',
    this.summary = '',
    this.riskWarning = '',
    this.status = 'pending',
    this.remarks = '',
    this.enableAlert = false,
    this.notifyChannels = '',
  });

  factory DailyOperationPlan.fromJson(Map<String, dynamic> json) {
    return DailyOperationPlan(
      id: _parseInt(json['id']) ?? _parseInt(json['ID']) ?? 0,
      planDate: json['planDate'] as String? ?? json['PlanDate'] as String? ?? '',
      stockCode: json['stockCode'] as String? ?? json['StockCode'] as String? ?? '',
      stockName: json['stockName'] as String? ?? json['StockName'] as String? ?? '',
      overallJudgment: json['overallJudgment'] as String? ?? json['OverallJudgment'] as String? ?? '',
      scenarios: json['scenarios'] as String? ?? json['Scenarios'] as String? ?? '',
      discipline: json['discipline'] as String? ?? json['Discipline'] as String? ?? '',
      summary: json['summary'] as String? ?? json['Summary'] as String? ?? '',
      riskWarning: json['riskWarning'] as String? ?? json['RiskWarning'] as String? ?? '',
      status: json['status'] as String? ?? json['Status'] as String? ?? 'pending',
      remarks: json['remarks'] as String? ?? json['Remarks'] as String? ?? '',
      enableAlert: json['enableAlert'] as bool? ?? json['EnableAlert'] as bool? ?? false,
      notifyChannels: json['notifyChannels'] as String? ?? json['NotifyChannels'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'planDate': planDate,
        'stockCode': stockCode,
        'stockName': stockName,
        'overallJudgment': overallJudgment,
        'scenarios': scenarios,
        'discipline': discipline,
        'summary': summary,
        'riskWarning': riskWarning,
        'status': status,
        'remarks': remarks,
        'enableAlert': enableAlert,
        'notifyChannels': notifyChannels,
      };

  /// 状态显示名
  String get statusLabel {
    switch (status) {
      case 'pending':
        return '待执行';
      case 'executing':
        return '执行中';
      case 'completed':
        return '已完成';
      case 'expired':
        return '已过期';
      default:
        return status;
    }
  }

  /// 解析情景方案列表
  List<OperationScenario> get scenarioList {
    try {
      final decoded = jsonDecode(scenarios);
      if (decoded is List) {
        return decoded
            .map((e) => OperationScenario.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// 每日操作计划分页结果
class DailyOperationPlanPageData {
  final List<DailyOperationPlan> list;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  DailyOperationPlanPageData({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory DailyOperationPlanPageData.fromJson(Map<String, dynamic> json) {
    final listJson = json['list'] as List<dynamic>? ?? [];
    return DailyOperationPlanPageData(
      list: listJson
          .map((e) => DailyOperationPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: _parseInt(json['total']) ?? 0,
      page: _parseInt(json['page']) ?? 1,
      pageSize: _parseInt(json['pageSize']) ?? 20,
      totalPages: _parseInt(json['totalPages']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
