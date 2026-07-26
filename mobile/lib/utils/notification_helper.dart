import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 本地推送通知工具类
class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 初始化通知插件（需在 main() 中调用）
  static Future<void> init() async {
    if (_initialized) return;

    final status = await Permission.notification.request();
    if (!status.isGranted) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // 创建通知渠道
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'price_alerts_up',
        '上涨提醒',
        description: '股票上涨价格提醒',
        importance: Importance.high,
        enableLights: true,
      ),
    );

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'price_alerts_down',
        '下跌提醒',
        description: '股票下跌价格提醒',
        importance: Importance.high,
        enableLights: true,
      ),
    );

    _initialized = true;
  }

  /// 发送涨跌提醒通知
  static Future<void> sendPriceAlert({
    required String stockCode,
    required String stockName,
    required double price,
    required double changePercent,
  }) async {
    if (!_initialized) return;

    final isUp = changePercent >= 0;
    final title = '$stockName ${isUp ? '上涨' : '下跌'}提醒';
    final body =
        '当前价格: ¥${price.toStringAsFixed(2)} (${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%)';

    const androidDetails = AndroidNotificationDetails(
      'price_alerts_up',
      '上涨提醒',
      channelDescription: '股票价格变动提醒',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      color: Color(0xFFE53935),
    );

    await _plugin.show(
      stockCode.hashCode.abs(),
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'stock:$stockCode',
    );
  }

  /// 发送通用通知
  static Future<void> sendNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'general',
      '一般通知',
      channelDescription: '一般提醒',
      importance: Importance.low,
      priority: Priority.low,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
