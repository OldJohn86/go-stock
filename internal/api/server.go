package api

import (
	"go-stock/backend/logger"

	"github.com/gin-gonic/gin"
)

// StartServer 启动 HTTP API 服务
func StartServer(addr string) {
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(CORSMiddleware(), LoggerMiddleware(), gin.Recovery())

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		success(c, gin.H{"status": "ok"})
	})

	// === API v1 路由 ===
	v1 := r.Group("/api/v1")
	{
		// 行情
		stock := v1.Group("/stock")
		{
			stock.GET("/real-time/:code", HandleGetStockRealTimePrice)
			stock.GET("/realtime-batch", HandleGetStockRealTimeBatch)
			stock.GET("/list", HandleGetAllStocks)
			stock.GET("/:code/kline", HandleGetStockKLineData)   // K线数据
			stock.GET("/:code/minute", HandleGetStockMinuteData) // 分时数据
		}

		// 自选
		follow := v1.Group("/follow")
		{
			follow.GET("/list", HandleGetFollowList)
			follow.POST("/follow", HandleFollowStock)
			follow.POST("/unfollow", HandleUnFollowStock)
		}

		// F10 财务数据
		f10 := v1.Group("/f10")
		{
			f10.GET("/latest-finance", HandleGetStockLatestFinance)
			f10.GET("/hk-finance", HandleGetHKStockLatestFinance)
		}

		// 交易日志
		trade := v1.Group("/trading")
		{
			trade.GET("/records", HandleGetTradingRecordList)
			trade.GET("/records/:id", HandleGetTradingRecordById)
			trade.POST("/records", HandleCreateTradingRecord)
			trade.PUT("/records/:id", HandleUpdateTradingRecord)
			trade.POST("/records/delete/:id", HandleDeleteTradingRecord)
			trade.GET("/statistics", HandleGetTradingRecordStatistics)
			trade.POST("/save", HandleSaveTradingRecord)
			trade.POST("/delete/:id", HandleDeleteTradingRecord)
			trade.GET("/export", HandleExportTradingRecords)
			trade.GET("/backtest", HandleGetBacktestAnalysis)
			trade.GET("/daily-pnl", HandleGetDailyPnL)
			trade.GET("/frequent-check", HandleCheckFrequentTrading)
		}

		// AI 对话
		agentGroup := v1.Group("/agent")
		{
			agentGroup.GET("/chat", HandleAgentChatSSE)  // SSE 流式
			agentGroup.POST("/chat", HandleAgentChat)    // JSON 非流式
		}

		// 每日操作计划
		plan := v1.Group("/operation-plan")
		{
			plan.GET("/list", HandleGetDailyOperationPlanList)
			plan.GET("/:id", HandleGetDailyOperationPlanByID)
			plan.POST("/save", HandleSaveDailyOperationPlan)
			plan.POST("/delete/:id", HandleDeleteDailyOperationPlan)
			plan.POST("/status", HandleUpdateDailyOperationPlanStatus)
		}

		// 自选股分组
		group := v1.Group("/group")
		{
			group.GET("/list", HandleGetGroupList)
			group.POST("/create", HandleCreateGroup)
			group.POST("/update", HandleUpdateGroup)
			group.POST("/delete/:id", HandleDeleteGroup)
			group.POST("/sort", HandleUpdateGroupSort)
			group.GET("/stocks", HandleGetGroupStocks)
			group.POST("/add-stock", HandleAddStockToGroup)
			group.POST("/remove-stock", HandleRemoveStockFromGroup)
			group.GET("/all-stocks", HandleGetAllGroupStocks)
		}

		// 大盘指数
		indices := v1.Group("/index")
		{
			indices.GET("/list", HandleGetIndexList)
		}

		// 市场数据
		market := v1.Group("/market")
		{
			market.GET("/industry-money-rank", HandleGetIndustryMoneyRank)
			market.GET("/industry-valuation", HandleGetIndustryValuation)
			market.GET("/concept-fund-flow", HandleGetConceptFundFlowRank)
			market.GET("/sector-stocks", HandleGetSectorStocks)
			market.GET("/hot-stocks", HandleGetHotStocks)
			market.GET("/hot-events", HandleGetHotEvents)
			market.GET("/hot-topics", HandleGetHotTopics)
			market.GET("/long-tiger", HandleGetLongTiger)
			market.GET("/stock-notice", HandleGetStockNotice)
		}

		// 价格预警
		alert := v1.Group("/alert")
		{
			alert.GET("/setting/:stockCode", HandleGetAlarmSetting)
			alert.POST("/setting", HandleSetAlarmSetting)
			alert.GET("/list", HandleGetAlarmList)
		}

		// AI 推荐股票
		aiRecommend := v1.Group("/ai-recommend")
		{
			aiRecommend.GET("/list", HandleGetAiRecommendStocksList)
			aiRecommend.POST("/alert", HandleUpdateAiRecommendAlert)
			aiRecommend.POST("/delete/:id", HandleDeleteAiRecommendStock)
		}

		// 大盘仪表盘
		dashboard := v1.Group("/dashboard")
		{
			dashboard.GET("/overview", HandleGetDashboardOverview)
			dashboard.GET("/portfolio", HandleGetDashboardPortfolio)
		}

		// 行情雷达 & 预警监控
		radar := v1.Group("/radar")
		{
			radar.GET("/overview", HandleGetMarketRadar)
			radar.GET("/money-flow", HandleGetRadarMoneyFlow)
			radar.GET("/uplimit-hot", HandleGetRadarUplimitHot)
			radar.GET("/monitor-status", HandleGetAlertMonitorStatus)
			radar.POST("/monitor-start", HandleStartAlertMonitor)
			radar.POST("/monitor-stop", HandleStopAlertMonitor)

			// 推送设备 Token 管理
			push := v1.Group("/push")
			{
				push.POST("/register-token", HandleRegisterPushToken)
				push.POST("/unregister-token", HandleUnregisterPushToken)
			}
		}

		// 设置
		settings := v1.Group("/settings")
		{
			settings.GET("", HandleGetSettings)
			settings.GET("/ai-configs", HandleGetAiConfigs)
			settings.GET("/fetch-models", HandleFetchAiModels)
			settings.GET("/test-connection", HandleTestAiConnection)
		}

		tdx := v1.Group("/tdx")
		{
			tdx.GET("/minute-time/:code", HandleGetTdxMinuteTime)
			tdx.GET("/history-minute-time/:code", HandleGetTdxHistoryMinuteTime)
			tdx.GET("/transactions/:code", HandleGetTdxTransactions)
			tdx.GET("/all-transactions/:code", HandleGetTdxAllTransactions)
			tdx.GET("/history-transactions/:code", HandleGetTdxHistoryTransactions)
			tdx.GET("/call-auction/:code", HandleGetTdxCallAuction)
			tdx.GET("/company-info/:code", HandleGetTdxCompanyInfo)
			tdx.GET("/finance-info/:code", HandleGetTdxFinanceInfo)
			tdx.GET("/xdxr-info/:code", HandleGetTdxXDXRInfo)
			tdx.GET("/company-categories/:code", HandleGetTdxCompanyCategoryList)
			tdx.GET("/company-category-content/:code", HandleGetTdxCompanyCategoryContent)
			tdx.GET("/symbol-boards/:code", HandleGetTdxSymbolBelongBoard)
			tdx.GET("/chip-distribution/:code", HandleGetChipDistribution)
			tdx.GET("/kline/:code", HandleGetEastMoneyKLine)
			tdx.GET("/kline-fallback/:code", HandleGetKLineWithFallback)
		}

		// K线形态识别
		kline := v1.Group("/kline")
		{
			kline.GET("/pattern/:code", HandleAnalyzeKLinePattern)
			kline.GET("/pattern-summary/:code", HandleGetKLinePatternSummary)
		}

		// 风控管理
		dashboardRisk := v1.Group("/dashboard")
		{
			dashboardRisk.GET("/risk-report", HandleGetRiskReport)
			dashboardRisk.GET("/positions", HandleGetPositions)
			dashboardRisk.POST("/position/add", HandleAddPosition)
			dashboardRisk.POST("/position/update", HandleUpdatePosition)
			dashboardRisk.POST("/position/delete/:id", HandleDeletePosition)
			dashboardRisk.GET("/recent-trades", HandleGetRecentTrades)
		}

		// 风险分析（来自 goldstock 合并）
		risk := v1.Group("/risk")
		{
			risk.GET("/portfolio", HandleGetRiskPortfolio)
			risk.POST("/discipline", HandleCheckDiscipline)
			risk.POST("/trades", HandleAddTrade)
			risk.POST("/analysis/run", HandleRunRiskAnalysis)
			risk.GET("/analysis/last", HandleGetLastRiskAnalysis)
		}

		// 定时任务管理
		cronTasks := v1.Group("/cron-tasks")
		{
			cronTasks.GET("/list", HandleGetCronTaskList)
			cronTasks.POST("/create", HandleCreateCronTask)
			cronTasks.POST("/update", HandleUpdateCronTask)
			cronTasks.POST("/delete/:id", HandleDeleteCronTask)
			cronTasks.POST("/enable/:id", HandleEnableCronTask)
			cronTasks.POST("/execute/:id", HandleExecuteCronTaskNow)
			cronTasks.GET("/types", HandleGetCronTaskTypes)
		}

		// MCP 服务管理
		mcpServers := v1.Group("/mcp-servers")
		{
			mcpServers.GET("/list", HandleGetMCPServerList)
			mcpServers.POST("/create", HandleCreateMCPServer)
			mcpServers.POST("/update", HandleUpdateMCPServer)
			mcpServers.POST("/delete/:id", HandleDeleteMCPServer)
			mcpServers.POST("/enable/:id", HandleEnableMCPServer)
			mcpServers.POST("/test/:id", HandleTestMCPServer)
			mcpServers.GET("/tools/:id", HandleGetMCPServerTools)
		}
	}

	logger.SugaredLogger.Infof("API server listening on %s", addr)
	if err := r.Run(addr); err != nil {
		logger.SugaredLogger.Fatalf("API server failed: %v", err)
	}
}
