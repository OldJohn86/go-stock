import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/push_api.dart';

/// 本地通知服务
/// 处理设备本地通知的显示和 FCM 推送 Token 注册
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  final PushApi _pushApi = PushApi();

  bool _initialized = false;
  String? _deviceToken;

  /// 初始化本地通知
  Future<void> init() async {
    if (_initialized) return;

    // 初始化本地通知设置
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    // 可在此处理通知点击后的页面跳转
    debugPrint('通知点击: ${response.payload}');
  }

  /// 显示本地通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'stock_alert_channel',
      '股票预警',
      channelDescription: '股票价格预警和通知',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 显示预警通知
  Future<void> showAlertNotification(String title, String body) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'alert',
    );
  }

  /// 获取 FCM 设备 Token 并注册到后端
  /// 需要 firebase_messaging 配置完成后调用
  Future<String?> getFcmToken() async {
    // FCM Token 获取需要 firebase_messaging 包和 Firebase 项目配置
    // 配置完成后取消以下注释
    /*
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _deviceToken = token;
        await _pushApi.registerToken(
          token,
          Platform.isAndroid ? 'android' : 'ios',
        );
        // 监听 Token 刷新
        messaging.onTokenRefresh.listen((newToken) {
          _deviceToken = newToken;
          _pushApi.registerToken(
            newToken,
            Platform.isAndroid ? 'android' : 'ios',
          );
        });
      }
      return token;
    } catch (e) {
      debugPrint('获取 FCM Token 失败: $e');
      return null;
    }
    */
    return null;
  }

  /// 取消注册 FCM Token
  Future<void> unregisterFcmToken() async {
    if (_deviceToken != null && _deviceToken!.isNotEmpty) {
      await _pushApi.unregisterToken(_deviceToken!);
    }
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    // Android 12+ 需要运行时权限
    if (Platform.isAndroid) {
      try {
        final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      } catch (_) {
        return false;
      }
    }

    // iOS 权限在初始化 DarwinInitializationSettings 时已请求
    return true;
  }
}
