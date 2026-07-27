package api

import (
	"strconv"
	"strings"

	"go-stock/backend/data"
	"go-stock/backend/models"
	"go-stock/backend/service"

	"github.com/duke-git/lancet/v2/convertor"
	"github.com/gin-gonic/gin"
)

// riskSvc 风控/持仓/交易领域的统一服务层（与 goldstock 合并后）。
var riskSvc = service.NewRiskService()

// HandleGetRiskReport 获取风控评估报告
// GET /api/v1/dashboard/risk-report
func HandleGetRiskReport(c *gin.Context) {
	cfg := data.GetSettingConfig()
	sdApi := data.NewStockDataApi()
	portfolioApi := data.NewPortfolioApi(cfg.Settings)

	// 获取持仓
	allPositions := portfolioApi.GetPositions()
	var codes []string
	for _, p := range allPositions {
		codes = append(codes, p.StockCode)
	}

	// 构建实时价格映射
	priceMap := make(map[string]data.PriceInfo)
	if len(codes) > 0 {
		infos, err := sdApi.GetStockCodeRealTimeData(codes...)
		if err == nil && infos != nil {
			for _, info := range *infos {
				price, _ := convertor.ToFloat(info.Price)
				prevClose, _ := convertor.ToFloat(info.PreClose)
				priceMap[strings.ToLower(info.Code)] = data.PriceInfo{
					Current:   price,
					PrevClose: prevClose,
				}
			}
		}
	}

	positionsWithPnL := portfolioApi.GetPositionsWithPnL(priceMap)
	cash := portfolioApi.CashAmount()
	totalInvested := 0.0
	for _, pos := range positionsWithPnL {
		totalInvested += pos.CostPrice * float64(pos.Position.Quantity)
	}

	cashPct := 0.0
	if totalInvested+cash > 0 {
		cashPct = cash / (totalInvested + cash) * 100
	}

	// 获取近期交易记录
	tradeApi := data.NewTradeApi(cfg.Settings)
	trades := tradeApi.GetRecentTrades("", 30)

	// 计算风险评分
	riskApi := data.NewRiskApi(cfg.Settings)
	report := riskApi.CalculateRiskScore(positionsWithPnL, cashPct, trades)

	success(c, report)
}

// HandleAddPosition 新增持仓
// POST /api/v1/dashboard/position/add
func HandleAddPosition(c *gin.Context) {
	var pos models.Position
	if err := c.ShouldBindJSON(&pos); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	cfg := data.GetSettingConfig()
	err := data.NewPortfolioApi(cfg.Settings).AddPosition(pos)
	if err != nil {
		fail(c, "添加失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "添加成功"})
}

// HandleUpdatePosition 更新持仓
// POST /api/v1/dashboard/position/update
func HandleUpdatePosition(c *gin.Context) {
	var pos models.Position
	if err := c.ShouldBindJSON(&pos); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	if pos.ID == 0 {
		badRequest(c, "缺少持仓ID")
		return
	}
	cfg := data.GetSettingConfig()
	err := data.NewPortfolioApi(cfg.Settings).UpdatePosition(pos)
	if err != nil {
		fail(c, "更新失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}

// HandleDeletePosition 删除持仓
// POST /api/v1/dashboard/position/delete/:id
func HandleDeletePosition(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的持仓ID")
		return
	}
	cfg := data.GetSettingConfig()
	err = data.NewPortfolioApi(cfg.Settings).DeletePosition(uint(id))
	if err != nil {
		fail(c, "删除失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}

// HandleGetRecentTrades 获取近期交易
// GET /api/v1/dashboard/recent-trades?stockCode=&days=30
func HandleGetRecentTrades(c *gin.Context) {
	stockCode := c.Query("stockCode")
	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))
	if days <= 0 {
		days = 30
	}
	cfg := data.GetSettingConfig()
	trades := data.NewTradeApi(cfg.Settings).GetRecentTrades(stockCode, days)
	success(c, trades)
}

// HandleGetPositions 获取持仓列表（含实时盈亏）
// GET /api/v1/dashboard/positions
func HandleGetPositions(c *gin.Context) {
	cfg := data.GetSettingConfig()
	sdApi := data.NewStockDataApi()
	portfolioApi := data.NewPortfolioApi(cfg.Settings)

	followList := sdApi.GetFollowList(0)
	var codes []string
	for _, st := range *followList {
		codes = append(codes, st.StockCode)
	}

	priceMap := make(map[string]data.PriceInfo)
	if len(codes) > 0 {
		infos, err := sdApi.GetStockCodeRealTimeData(codes...)
		if err == nil && infos != nil {
			for _, info := range *infos {
				price, _ := convertor.ToFloat(info.Price)
				prevClose, _ := convertor.ToFloat(info.PreClose)
				priceMap[strings.ToLower(info.Code)] = data.PriceInfo{
					Current:   price,
					PrevClose: prevClose,
				}
			}
		}
	}

	allPositions := portfolioApi.GetPositions()
	_ = allPositions
	positions := portfolioApi.GetPositionsWithPnL(priceMap)
	cash := portfolioApi.CashAmount()

	totalPnL := 0.0
	totalPnLPct := 0.0
	totalMarketValue := 0.0
	winCount := 0
	loseCount := 0
	for _, pos := range positions {
		totalPnL += pos.PnLAmount
		totalMarketValue += pos.CurrentPrice * float64(pos.Position.Quantity)
		if pos.PnLPct >= 0 {
			winCount++
		} else {
			loseCount++
		}
	}
	if totalMarketValue > 0 {
		totalPnLPct = totalPnL / totalMarketValue * 100
	}

	totalAssets := cfg.Settings.TotalCapital + totalPnL

	success(c, gin.H{
		"positions":        positions,
		"totalPnL":         totalPnL,
		"totalPnLPct":      totalPnLPct,
		"totalMarketValue": totalMarketValue,
		"totalAssets":      totalAssets,
		"cash":             cash,
		"winCount":         winCount,
		"loseCount":        loseCount,
		"investedCapital":  totalMarketValue - totalPnL,
	})
}

// HandleGetRiskPortfolio 获取持仓列表（含实时盈亏）
// GET /api/v1/risk/portfolio
func HandleGetRiskPortfolio(c *gin.Context) {
	success(c, riskSvc.Portfolio())
}

// HandleCheckDiscipline 检查交易纪律规则
// POST /api/v1/risk/discipline
func HandleCheckDiscipline(c *gin.Context) {
	var req data.TradeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	success(c, riskSvc.CheckDiscipline(req))
}

// HandleAddTrade 添加交易记录（买入/卖出，卖出自动扣减持仓）
// POST /api/v1/risk/trades
func HandleAddTrade(c *gin.Context) {
	var trade models.Trade
	if err := c.ShouldBindJSON(&trade); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	if err := riskSvc.AddTrade(trade); err != nil {
		fail(c, "添加交易失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "添加成功"})
}

// HandleRunRiskAnalysis 执行 AI 风控分析
// POST /api/v1/risk/analysis/run
func HandleRunRiskAnalysis(c *gin.Context) {
	result, err := riskSvc.RunRiskAnalysis(nil)
	if err != nil {
		fail(c, "风控分析失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetLastRiskAnalysis 获取最近一次风控分析结果
// GET /api/v1/risk/analysis/last
func HandleGetLastRiskAnalysis(c *gin.Context) {
	success(c, riskSvc.LastRiskAnalysis())
}
