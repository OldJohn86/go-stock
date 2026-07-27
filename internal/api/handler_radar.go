package api

import (
	"strconv"
	"time"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetMarketRadar 获取行情雷达数据
// GET /api/v1/radar/overview
func HandleGetMarketRadar(c *gin.Context) {
	newsApi := data.NewMarketNewsApi()

	// 1. 涨停热点（昨日/今日）
	today := time.Now().Format("2006-01-02")
	uplimitHot := newsApi.GetUplimitHot(today, 20)

	// 2. 行业板块涨幅排名
	industryRank := newsApi.GetIndustryRank("averatio", 10)

	// 3. 个股主力资金流向（净流入 TOP 20 / 净流出 TOP 20）
	moneyFlow := newsApi.GetMoneyRankSina("netamount")
	moneyInTop := make([]map[string]any, 0)
	moneyOutTop := make([]map[string]any, 0)
	for _, item := range moneyFlow {
		netAmount, ok := item["netamount"]
		netFloat := 0.0
		if ok {
			switch v := netAmount.(type) {
			case float64:
				netFloat = v
			case string:
				netFloat, _ = strconv.ParseFloat(v, 64)
			}
		}
		if netFloat >= 0 && len(moneyInTop) < 20 {
			moneyInTop = append(moneyInTop, item)
		} else if netFloat < 0 && len(moneyOutTop) < 20 {
			moneyOutTop = append(moneyOutTop, item)
		}
	}

	// 5. 雪球热门股票
	hotStocks := newsApi.XUEQIUHotStock(20, "0")

	success(c, gin.H{
		"uplimitHot":   uplimitHot,
		"industryRank": industryRank,
		"moneyInTop":   moneyInTop,
		"moneyOutTop":  moneyOutTop,
		"hotStocks":    hotStocks,
	})
}

// HandleGetRadarMoneyFlow 获取个股资金流向（指定代码）
// GET /api/v1/radar/money-flow?code=sh600519&days=5
func HandleGetRadarMoneyFlow(c *gin.Context) {
	code := c.Query("code")
	daysStr := c.DefaultQuery("days", "5")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days <= 0 {
		days = 5
	}
	if days > 30 {
		days = 30
	}

	if code == "" {
		badRequest(c, "请传入股票代码")
		return
	}

	newsApi := data.NewMarketNewsApi()
	trend := newsApi.GetStockMoneyTrendByDay(code, days)

	success(c, gin.H{
		"code":  code,
		"days":  days,
		"trend": trend,
	})
}

// HandleGetRadarUplimitHot 获取涨停热点详情
// GET /api/v1/radar/uplimit-hot?date=2026-07-25&limit=20
func HandleGetRadarUplimitHot(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))
	limitStr := c.DefaultQuery("limit", "20")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	newsApi := data.NewMarketNewsApi()
	result := newsApi.GetUplimitHot(date, limit)

	success(c, result)
}

// HandleGetAlertMonitorStatus 获取预警监控状态
// GET /api/v1/radar/monitor-status
func HandleGetAlertMonitorStatus(c *gin.Context) {
	svc := data.GetAlertMonitorService()
	success(c, gin.H{
		"running": svc.IsRunning(),
	})
}

// HandleStartAlertMonitor 启动预警监控
// POST /api/v1/radar/monitor-start
func HandleStartAlertMonitor(c *gin.Context) {
	svc := data.GetAlertMonitorService()
	msg := svc.Start()
	success(c, gin.H{"message": msg, "running": svc.IsRunning()})
}

// HandleStopAlertMonitor 停止预警监控
// POST /api/v1/radar/monitor-stop
func HandleStopAlertMonitor(c *gin.Context) {
	svc := data.GetAlertMonitorService()
	msg := svc.Stop()
	success(c, gin.H{"message": msg, "running": svc.IsRunning()})
}
