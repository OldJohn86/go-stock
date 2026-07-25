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
			trade.GET("/statistics", HandleGetTradingRecordStatistics)
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
	}

	logger.SugaredLogger.Infof("API server listening on %s", addr)
	if err := r.Run(addr); err != nil {
		logger.SugaredLogger.Fatalf("API server failed: %v", err)
	}
}
