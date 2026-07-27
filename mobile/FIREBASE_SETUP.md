# Firebase Cloud Messaging 推送集成指南

后端已包含 FCM 推送服务代码（`backend/data/fcm_api.go`），Flutter 端的本地通知（`flutter_local_notifications`）也已配置好。要实现完整的 FCM 远程推送，需要完成以下步骤：

## 1. 创建 Firebase 项目

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 创建新项目（或使用已有项目）
3. 在项目设置中注册 Android 应用：
   - Android 包名：在 `android/app/build.gradle` 中查看 `applicationId`
   - 下载 `google-services.json` 并放到 `android/app/` 目录
4. 注册 iOS 应用（选做）：
   - 下载 `GoogleService-Info.plist` 并放到 `ios/Runner/` 目录

## 2. 配置 Flutter

在 `mobile/pubspec.yaml` 中取消 firebase 依赖注释：
```yaml
firebase_core: ^3.12.1
firebase_messaging: ^15.2.4
```

Android 配置已在 `android/build.gradle` 中添加 Google Services 插件依赖。

然后运行：
```bash
cd mobile
flutter pub get
```

## 3. 获取 FCM Server Key

1. Firebase Console → 项目设置 → 云消息传递
2. 复制**服务器密钥**（Server Key）
3. 在 go-stock 设置中配置：
   - `FcmPushEnable` = true
   - `FcmProjectId` = Firebase 项目 ID
   - `FcmServerKey` = 上一步复制的服务器密钥

## 4. 验证推送

1. 启动 go-stock 后端服务
2. 启动 Flutter 应用（会向后端注册设备 Token）
3. 在 App 设置中启用「预警监控」
4. 添加一条股票预警（设置变动百分比或价格）
5. 当条件触发时，会通过 FCM 推送通知到手机

## 架构说明

```
AlertMonitorService (后端)
  │
  ├─ DingTalk ──────── SendToDingDing()
  ├─ Feishu ────────── SendToFeishu()
  ├─ Local (macOS) ── AlertWindowsApi.SendNotification()
  └─ FCM ───────────── GetFcmApi().PushToAllDevices()
                          │
                    Firebase Cloud Messaging
                          │
                    Flutter App (设备)
                          │
                    NotificationHelper.show()
```

## 注意事项

- FCM 推送需要后端服务器能访问 `fcm.googleapis.com`
- Android 端需要 Google Play Services
- iOS 端需要 APNs 证书（可在 Firebase Console 上传）
- 国内网络环境下，可能需要代理才能连接 Firebase
