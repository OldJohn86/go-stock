# go-stock 移动端迁移方案

> 基于 go-stock 桌面版（Go + Wails）迁移为移动端 App 的技术方案分析

## 一、项目背景

go-stock 是一款基于 **Go + Wails** 框架构建的个人股票投资辅助工具，核心能力包括：

- 行情数据接入（东方财富等数据源，覆盖 A/港/美股）
- AI 智能分析助手（多 Agent 模式、记忆对话、工具调用）
- 交易日志管理（FIFO 持仓成本与盈亏计算）
- 每日操作计划（AI 生成方案 + 盘中价格预警）
- 自选股分组管理 + 盘中监控
- 财务分析（F10）、技术指标、融资融券等

当前架构：

```
Vue 前端 (桌面布局) ←Wails 绑定→ Go 业务层 (backend/)
```

Wails 将 Go 后端与 Web 前端打包为原生桌面应用。前端通过 Wails binding 直接调用 Go 方法，没有独立的 HTTP 服务层。

## 二、三种迁移方案对比

### 方案一：Go API 服务 + 移动端重写 UI（推荐 ✅）

```
移动端 UI (Flutter)
    ↕  HTTP/REST + WebSocket
Go HTTP 服务层 (Gin/Echo) ← 新增
    ↕
Go 业务层 (backend/) ← 完全复用
```

| 优点 | 缺点 |
|------|------|
| 后端完全复用，业务逻辑零改动 | 移动端 UI 全量重写 |
| 架构最清晰，前后端彻底解耦 | 需新增 HTTP 路由层 |
| 便于后续扩展（Web 版、小程序等） | |
| 支持移动端原生推送（APNs/FCM） | |
| Flutter 自绘引擎适合行情图表 | |

### 方案二：gomobile 编译 Go 库嵌入 Flutter

```
Flutter UI
    ↕  Method Channel
Go (编译为 .so / .aar) ← gomobile bind + FFI
```

| 优点 | 缺点 |
|------|------|
| 无需网络层，本地调用延迟低 | gomobile 在 iOS 有限制（net/http 表现受限） |
| 离线可用 | 调试困难，调用链深 |
| | Go 三方库可能不兼容移动端编译 |
| | 无法单独升级后端逻辑（需发版） |

### 方案三：Capacitor/PWA 套壳

```
Capacitor 壳 (WebView)
    ↕
Vue 前端 (适配移动端布局) ← 仍需大量改
    ↕
Go HTTP 服务 (内嵌)
```

| 优点 | 缺点 |
|------|------|
| 前端代码有一定复用度 | 移动端布局几乎要重写（现有桌面组件不可用） |
| 上架速度快 | WebView 性能差，K 线图表卡顿 |
| | 推送、本地存储等能力需通过 Bridge 实现 |

### 综合对比

| 维度 | 方案一（Go API+Flutter） | 方案二（gomobile+Flutter） | 方案三（Capacitor 套壳） |
|------|:---:|:---:|:---:|
| UI 重写量 | 全量 | 全量 | 大部分 |
| 后端复用度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 实时行情性能 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐（FFI 开销） | ⭐⭐（WebView） |
| AI 对话体验 | ⭐⭐⭐⭐⭐（原生） | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 推送通知 | 原生支持 | 需额外 Bridge | 需 Capacitor 插件 |
| 维护复杂度 | 低 | 高 | 中 |
| 后续可扩展性 | 高（多端复用 API） | 低（耦合紧） | 低 |
| 开发上手难度 | 中 | 高 | 低（但体验差） |

## 三、推荐方案：Go API + Flutter

### 核心理由

**1. 这个项目的后端才是核心价值**

最有价值的资产全部在 `backend/` 下，与 UI 解耦良好：

- `backend/data/stock_data_api.go` — 东方财富等 10+ 数据源封装
- `backend/agent/agent_api.go` — AI Agent 系统（React/PlanExecute 模式、记忆管理、工具调用）
- `backend/data/` — 交易 FIFO 计算、F10 财务分析、K 线形态识别
- `backend/models/` — 数据模型定义

以上代码可以零改动直接暴露为 REST API。

**2. Vue 前端在移动端几乎没有复用价值**

现有前端组件均为桌面设计：

| 组件 | 布局特点 | 移动端适配难度 |
|------|---------|:---:|
| DailyOperationPlan.vue | 表格 + 多标签页 | ❌ 几乎重写 |
| TradingRecordManager.vue | 复杂数据管理 + 筛选 | ❌ 几乎重写 |
| researchIndex.vue | 桌面多栏布局 | ❌ 几乎重写 |
| FloatingAgentAssistant.vue | 悬浮窗 + 对话框 | ⚠️ 部分参考 |

套壳方案（方案三）省不了多少前端工作量，还多一层 WebView 的性能损耗。

**3. Flutter 适合行情类 App**

行情图表（K 线、分时图）是核心高频场景。Flutter 自绘引擎（Skia/Impeller）可以：

- 流畅渲染大量 K 线数据点（对比 RN 的 Native Bridge 模式）
- 自定义绘制技术指标叠加、MACD/KDJ 等
- 60fps 的列表滚动与动画
- 社区有成熟的图表库（fl_chart, sparkline 等，或 CustomPainter 自绘）

**4. AI 对话原生体验更好**

桌面版的 AI Agent 对话是流式输出（SSE/WebSocket），Flutter 原生支持 StreamBuilder 流畅渲染流式文本，比 WebView 中的 JS 实现更顺滑。

## 四、分阶段迁移计划

### Phase 1：Go 后端加 HTTP 层（预估 3-5 天）

**目标**：将 Wails binding 层的 API 方法暴露为 RESTful API

**具体工作**：

1. 引入 Gin 框架（或 Echo，推荐 Gin 因为社区大、文档多、中间件丰富）
2. 将 `app.go` / `app_common.go` 中的关键方法映射为路由：

| Wails 绑定方法 | REST 路由 | 说明 |
|------|---------|------|
| GetStockRealTimePrice | `GET /api/v1/stock/:code/price` | 实时行情 |
| GetAllStocks | `GET /api/v1/stocks` | 股票列表 |
| GetTradingRecordList | `GET /api/v1/trading-records` | 交易日志 |
| GetTradingRecordStatistics | `GET /api/v1/trading-records/statistics` | 交易统计 |
| ChatWithAgent | `POST /api/v1/agent/chat` (SSE) | AI 对话（流式） |
| GetDailyOperationPlanList | `GET /api/v1/operation-plans` | 操作计划 |
| FollowStock | `POST /api/v1/stocks/follow` | 自选关注 |

3. 新增 `cmd/server/main.go` 作为 HTTP 服务入口
4. 添加 WebSocket 支持用于实时行情推送

**代码结构变化**：

```
go-stock/
├── cmd/
│   └── server/
│       └── main.go          ← 新增：HTTP 服务入口
├── internal/
│   └── api/
│       ├── router.go        ← 新增：路由注册
│       ├── handler_stock.go ← 新增：行情接口
│       ├── handler_trade.go ← 新增：交易接口
│       ├── handler_agent.go ← 新增：AI 对话接口（SSE）
│       └── middleware.go    ← 新增：日志/鉴权/跨域
├── backend/                 ← 完全复用，零改动
├── app.go                   ← 保留（桌面版兼容）
├── main.go                  ← 保留（桌面版入口）
```

### Phase 2：Flutter 壳工程 + 核心功能（预估 2-3 周）

**目标**：跑通 Flutter ←→ Go API 完整链路，实现最核心功能

**优先级排序**：

1. **行情列表** — 自选股列表 + 实时价格刷新（WebSocket）
2. **K 线详情页** — 日/周/月 K 线 + 分时图 + 技术指标
3. **自选管理** — 加/删自选、分组、排序
4. **导航框架** — Tab 导航 + 路由结构搭建

### Phase 3：AI 对话 + 交易日志（预估 2-3 周）

1. **AI 对话页** — 流式消息渲染、历史对话、Agent 工具调用展示
2. **交易日志** — 记录管理、筛选、统计看板
3. **每日操作计划** — 列表 + 详情 + 状态管理

### Phase 4：推送通知（预估 1 周）

1. APNs (iOS) / FCM (Android) 接入
2. 盘中预警推送替换桌面通知（AlertWindows API）
3. 后台定时任务（`cron` 迁移方案：iOS Background Fetch / Android WorkManager）

### Phase 5：剩余功能（按需）

- 财务分析 F10
- 技术指标/形态分析
- 融资融券数据
- 基金查询等辅助功能

## 五、技术选型建议

| 组件 | 推荐 | 说明 |
|------|------|------|
| HTTP 框架 | **Gin** | 性能好、社区大、中间件丰富 |
| API 文档 | **Swaggo** (swag) | 自动从 Go 注释生成 OpenAPI 文档，Flutter 端可生成客户端 |
| 跨平台框架 | **Flutter** | 性能好、自绘引擎适合图表、单一代码库 |
| 状态管理 | **Riverpod** 或 **Bloc** | 推荐 Riverpod，简洁且测试友好 |
| 网络层 | **Dio** | Flutter 最主流 HTTP 客户端 |
| 图表库 | **CustomPainter 自绘** | K 线/分时图建议自绘（社区库灵活度不够）或参考 **fl_chart** |
| 本地存储 | **Isar** 或 **Hive** | 离线缓存行情数据，Isar 性能最好 |

## 六、关键注意事项

### 1. 现有桌面版兼容

- Phase 1 新增的 HTTP 层不应破坏现有 Wails 桌面版本的运行
- 建议新建 `cmd/server/main.go`，不修改 `main.go` 和 `app.go`
- `backend/` 下的代码完全共享，只新增不修改

### 2. 行情数据实时推送

桌面版使用轮询（60s 定时器），移动端应改用 WebSocket：

```
浏览器 ←JSON Polling→  桌面版
移动端 ←WebSocket Stream→  API 服务
```

Go 端的 Gin 可以配合 `gorilla/websocket` 实现 WebSocket 端点。

### 3. AI 对话流式传输

桌面版通过 Wails EventsEmit 推送到前端：

```go
// 现状：Wails 事件
runtime.EventsEmit(a.ctx, "agent-message", msg)

// 改造：HTTP SSE
// GET /api/v1/agent/chat?question=...
// 响应: text/event-stream
```

Flutter 端使用 `dart:io` 的 `HttpClient` 或 `eventsource` 包消费 SSE 流。

### 4. 数据库策略

桌面版使用本地 SQLite，移动端同样可以使用 SQLite（Flutter 端用 `sqflite` 或 `drift`）：

```
桌面版: Go GORM + SQLite (本地)
移动端: Flutter drift/sqflite + SQLite (本地)
API 侧: Go GORM + SQLite (服务端，可选)
```

如果希望移动端离线可用，可以在设备本地跑 SQLite，API 作为同步源。

### 5. 通知推送

```
桌面版: AlertWindows API (桌面弹窗) + 飞书/钉钉 Webhook
移动端: APNs (iOS) / FCM (Android) + 飞书/钉钉 Webhook
```

方案：新增 `backend/notify/` 模块统一推送接口，同时支持桌面和移动端通道。

## 七、项目结构展望

迁移完成后，项目将同时支持两个入口：

```
go-stock/
├── cmd/
│   ├── desktop/
│   │   └── main.go          ← 现有桌面版入口（main.go 迁入）
│   └── server/
│       └── main.go          ← 新增：API 服务入口
├── internal/
│   └── api/                 ← 新增：HTTP API 层
│       ├── router.go
│       ├── handler/
│       │   ├── stock.go
│       │   ├── trade.go
│       │   ├── agent.go
│       │   └── plan.go
│       └── middleware.go
├── backend/                 ← 核心业务（共享）
│   ├── data/
│   ├── agent/
│   ├── models/
│   ├── db/
│   └── logger/
├── app.go                   ← 保留，桌面版使用
├── frontend/                ← 桌面版 Vue 前端，逐步不再维护
└── mobile/                  ← 新增：Flutter 项目
    └── lib/
        ├── main.dart
        ├── api/             ← API 客户端
        ├── pages/           ← 页面
        ├── widgets/         ← 组件
        └── models/          ← 数据模型
```

## 八、总结

| 问题 | 结论 |
|------|------|
| 哪种方案？ | **Go API 服务 (Gin) + Flutter 移动端** |
| 后端复用度？ | ~90% `backend/` 零改动复用 |
| UI 重写量？ | 全部重写，桌面 Vue 组件无复用价值 |
| 是否影响现有桌面版？ | 不影响，入口独立 |
| 推荐第一阶段？ | 先做 HTTP 层，让后端变成独立 API 服务 |
| Flutter 还是 RN？ | Flutter，性能更适合行情 App |
| 最快多久有 Demo？ | 2-3 周可跑通行情列表 + K 线 |

> **第一步建议**：从新增 `cmd/server/main.go` 和 Gin 路由层开始，将当前 `app.go` / `app_common.go` 中暴露的 API 方法逐一映射为 REST 端点。这一步完成后，即使不开发移动端，也能用 curl/Postman 调用所有功能——架构升级本身就有价值。
