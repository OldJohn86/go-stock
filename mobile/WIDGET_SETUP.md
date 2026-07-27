# 桌面小组件（Widget）集成指南

## 概述

为 stock-flutter 添加 iOS (WidgetKit) 和 Android (App Widget) 桌面小组件，让用户在手机桌面直接查看自选股行情、大盘指数或持仓盈亏。

> ⚠️ 小组件是原生平台功能，需要分别在 iOS 和 Android 项目中添加原生代码。
> 本指南提供完整的代码和步骤。

---

## 架构

```
┌─────────────────────────────────────────────────┐
│                  小组件 (Widget)                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ 自选行情   │ │ 大盘指数   │ │ 持仓盈亏          │ │
│  │ (3只股票)  │ │ (概览)    │ │ (总资产/收益)     │ │
│  └─────┬────┘ └────┬─────┘ └────────┬─────────┘ │
└────────┼───────────┼────────────────┼───────────┘
         │           │                │
         └───────────┼────────────────┘
                     │ (数据共享)
             ┌───────▼───────┐
             │  Flutter 主 App  │
             │  (数据更新器)     │
             └───────┬───────┘
                     │
             ┌───────▼───────┐
             │   Go 后端 API   │
             │  /api/v1/...   │
             └───────────────┘
```

---

## 一、添加 `home_widget` 依赖

```yaml
# mobile/pubspec.yaml 中已有
dependencies:
  home_widget: ^0.9.0
```

```bash
cd mobile
flutter pub add home_widget
```

> 如需临时测试，也可以使用 `shared_preferences` 传递数据，但 `home_widget` 提供了更完善的平台桥接。

---

## 二、Flutter 端数据服务

创建 `mobile/lib/services/widget_service.dart`：

```dart
import 'package:home_widget/home_widget.dart';

/// 桌面小组件数据更新服务
class WidgetService {
  static const String _widgetName = 'StockWidget';

  /// 更新自选股数据到小组件
  static Future<void> updateWatchlist(List<Map<String, dynamic>> stocks) async {
    // 取前 3 只股票
    final top3 = stocks.take(3).map((s) => {
      'name': s['name'] ?? '',
      'price': (s['price'] ?? 0).toStringAsFixed(2),
      'change': (s['change'] ?? 0).toStringAsFixed(2),
      'changePercent': (s['changePercent'] ?? 0).toStringAsFixed(2),
    }).toList();

    await HomeWidget.saveWidgetData('watchlist', top3);
    await HomeWidget.updateWidget(name: _widgetName, iOSName: _widgetName);
  }

  /// 更新大盘指数数据到小组件
  static Future<void> updateIndices(List<Map<String, dynamic>> indices) async {
    final data = indices.map((i) => {
      'name': i['name'] ?? '',
      'point': i['point'] ?? '',
      'change': i['change'] ?? '',
      'changePercent': i['changePercent'] ?? '',
    }).toList();

    await HomeWidget.saveWidgetData('indices', data);
    await HomeWidget.updateWidget(name: _widgetName, iOSName: _widgetName);
  }

  /// 更新持仓盈亏数据到小组件
  static Future<void> updatePortfolio(Map<String, dynamic> portfolio) async {
    await HomeWidget.saveWidgetData('portfolio', portfolio);
    await HomeWidget.updateWidget(name: _widgetName, iOSName: _widgetName);
  }

  /// 注册点击回调（用户点击小组件时打开对应页面）
  static Future<void> registerCallback() async {
    HomeWidget.widgetClickedUriCallback.listen((Uri? uri) {
      if (uri != null) {
        // 根据 uri 跳转到不同页面
        // uri: stock://watchlist, stock://index, stock://portfolio
      }
    });
  }
}
```

---

## 三、iOS 小组件（WidgetKit + SwiftUI）

### 3.1 创建 Widget Extension

在 Xcode 中：
1. 打开 `mobile/ios/Runner.xcworkspace`
2. File → New → Target → Widget Extension
3. 命名为 `StockWidget`，不勾选 "Include Configuration App Intent"

### 3.2 Swift 小组件代码

创建 `mobile/ios/StockWidget/StockWidget.swift`：

```swift
import WidgetKit
import SwiftUI
import Intents

// MARK: - 数据模型
struct StockEntry: TimelineEntry {
    let date: Date
    let watchlist: [WatchlistItem]
    let indices: [IndexItem]
    let portfolio: PortfolioItem?
}

struct WatchlistItem: Codable {
    let name: String
    let price: String
    let change: String
    let changePercent: String
}

struct IndexItem: Codable {
    let name: String
    let point: String
    let change: String
    let changePercent: String
}

struct PortfolioItem: Codable {
    let totalAssets: String?
    let totalPnL: String?
    let totalPnLPct: String?
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StockEntry {
        StockEntry(
            date: Date(),
            watchlist: [
                WatchlistItem(name: "茅台", price: "1888.00", change: "+12.00", changePercent: "+0.64%"),
                WatchlistItem(name: "腾讯", price: "388.00", change: "-5.00", changePercent: "-1.27%"),
            ],
            indices: [
                IndexItem(name: "上证", point: "3200", change: "+15", changePercent: "+0.47%"),
            ],
            portfolio: PortfolioItem(totalAssets: "100000", totalPnL: "+5000", totalPnLPct: "+5.0%")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StockEntry) -> Void) {
        let entry = StockEntry(
            date: Date(),
            watchlist: loadWatchlist(),
            indices: loadIndices(),
            portfolio: loadPortfolio()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StockEntry>) -> Void) {
        let entry = StockEntry(
            date: Date(),
            watchlist: loadWatchlist(),
            indices: loadIndices(),
            portfolio: loadPortfolio()
        )
        // 每 15 分钟刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWatchlist() -> [WatchlistItem] {
        guard let data = UserDefaults(suiteName: "group.com.example.stock")?.data(forKey: "watchlist"),
              let items = try? JSONDecoder().decode([WatchlistItem].self, from: data) else {
            return []
        }
        return items
    }

    private func loadIndices() -> [IndexItem] {
        guard let data = UserDefaults(suiteName: "group.com.example.stock")?.data(forKey: "indices"),
              let items = try? JSONDecoder().decode([IndexItem].self, from: data) else {
            return []
        }
        return items
    }

    private func loadPortfolio() -> PortfolioItem? {
        guard let data = UserDefaults(suiteName: "group.com.example.stock")?.data(forKey: "portfolio"),
              let item = try? JSONDecoder().decode(PortfolioItem.self, from: data) else {
            return nil
        }
        return item
    }
}

// MARK: - Widget 视图
struct StockWidgetEntryView: View {
    var entry: StockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.watchlist.isEmpty {
                Text("自选")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(entry.watchlist.prefix(3), id: \.name) { stock in
                    HStack {
                        Text(stock.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(stock.price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(stock.changePercent)
                            .font(.caption)
                            .foregroundColor(stock.changePercent.hasPrefix("+") ? .red : .green)
                    }
                }
            } else if let portfolio = entry.portfolio {
                Text("持仓")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text("总资产")
                        .font(.subheadline)
                    Spacer()
                    Text(portfolio.totalAssets ?? "-")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("盈亏")
                        .font(.subheadline)
                    Spacer()
                    Text(portfolio.totalPnL ?? "-")
                        .font(.subheadline)
                        .foregroundColor(portfolio.totalPnL?.hasPrefix("+") == true ? .red : .green)
                }
            } else {
                Text("请打开 App 刷新数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct StockWidget: Widget {
    let kind: String = "StockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("股票行情")
        .description("快速查看自选股行情和持仓盈亏")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

### 3.3 配置 App Group

1. Xcode → 项目设置 → Signing & Capabilities → + → App Groups
2. 添加 `group.com.example.stock`
3. 确保主 App Target 和 Widget Extension 都勾选同一个 App Group

---

## 四、Android 小组件

### 4.1 创建 Widget 布局

`mobile/android/app/src/main/res/layout/stock_widget.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@android:color/white">

    <TextView
        android:id="@+id/title"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="自选行情"
        android:textColor="@android:color/black"
        android:textSize="14sp" />

    <LinearLayout
        android:id="@+id/stock_list"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:layout_marginTop="8dp" />

</LinearLayout>
```

### 4.2 Widget 实现

`mobile/android/app/src/main/kotlin/.../widget/StockWidget.kt`：

```kotlin
package com.example.stock.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

class StockWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences("widget_data", Context.MODE_PRIVATE)
        val watchlistJson = prefs.getString("watchlist", "[]")
        val views = RemoteViews(context.packageName, R.layout.stock_widget)

        try {
            val arr = JSONArray(watchlistJson)
            if (arr.length() > 0) {
                val sb = StringBuilder()
                for (i in 0 until minOf(arr.length(), 3)) {
                    val obj = arr.getJSONObject(i)
                    sb.append("${obj.getString("name")}: ¥${obj.getString("price")}")
                    sb.append(" ${obj.getString("changePercent")}\n")
                }
                views.setTextViewText(R.id.stock_list, sb.toString().trim())
            }
        } catch (e: Exception) {
            views.setTextViewText(R.id.stock_list, "暂无数据")
        }

        // 点击打开 App
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.stock_list, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
```

### 4.3 Widget Info XML

`mobile/android/app/src/main/res/xml/stock_widget_info.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="900000"
    android:initialLayout="@layout/stock_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
```

### 4.4 注册 Widget

在 `mobile/android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<receiver android:name=".widget.StockWidget">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/stock_widget_info" />
</receiver>
```

---

## 五、在 App 中定期刷新小组件

在 `mobile/lib/services/notification_service.dart` 或新建定时服务中调用：

```dart
import 'package:home_widget/home_widget.dart';

/// 在 App 启动时调用
void initWidgetUpdates() {
  // 每 30 秒刷新一次小组件（仅在 App 前台时有效）
  Timer.periodic(const Duration(seconds: 30), (_) async {
    await _refreshWidgetData();
  });
}

Future<void> _refreshWidgetData() async {
  try {
    // 1. 获取自选股行情
    final stocks = await StockApi().getFollowListCached();
    await WidgetService.updateWatchlist(stocks);

    // 2. 获取大盘指数
    final indices = await StockApi().getMarketIndex();
    await WidgetService.updateIndices(indices);
  } catch (e) {
    // 静默失败
  }
}
```

---

## 六、测试验证

1. **iOS**:
   - Xcode 中运行 App，选择 iOS 17+ 模拟器
   - 回到主屏幕，长按空白区域 → + → 搜索 "StockWidget"
   - 添加到桌面，验证数据展示

2. **Android**:
   - `flutter build apk --debug`
   - 安装到设备
   - 长按桌面 → 小组件 → 找到 "股票行情"
   - 拖到桌面，验证显示

---

## 七、注意事项

- **iOS App Group**: 必须配置 App Group 才能让主 App 和 Widget Extension 共享 UserDefaults
- **Android 更新频率**: Android 小组件最小更新周期为 15 分钟（900000ms），可通过 JobScheduler 提高频率
- **数据安全**: 不要在小组件中展示敏感信息（如完整资金账号）
- **小组件尺寸**: iOS 支持 small/medium/large，建议优先适配 medium
- **点击跳转**: 可通过 URL Scheme（如 `stock://watchlist`）实现点击小组件跳转到对应页面
