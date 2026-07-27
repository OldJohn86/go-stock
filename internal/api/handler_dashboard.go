package api

import (
	"strings"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/duke-git/lancet/v2/convertor"
	"github.com/gin-gonic/gin"
)

// HandleGetDashboardOverview 获取大盘仪表盘概览
// GET /api/v1/dashboard/overview
func HandleGetDashboardOverview(c *gin.Context) {
	statApi := data.NewMarketStatisticApi()
	newsApi := data.NewMarketNewsApi()

	// 1. 市场情绪数据
	stats := statApi.GetTodayData()
	var latestStat *models.MarketStatistic
	if len(stats) > 0 {
		latestStat = &stats[len(stats)-1]
	}

	// 2. 行业资金流向 TOP 10
	industryMoneyRank := newsApi.GetIndustryMoneyRankSina("0", "netamount")
	industryTop := make([]map[string]any, 0)
	if len(industryMoneyRank) > 10 {
		industryTop = industryMoneyRank[:10]
	} else {
		industryTop = industryMoneyRank
	}

	// 3. 概念资金流向 TOP 5
	conceptMoneyRank := newsApi.GetIndustryMoneyRankSina("1", "netamount")
	conceptTop := make([]map[string]any, 0)
	if len(conceptMoneyRank) > 5 {
		conceptTop = conceptMoneyRank[:5]
	} else {
		conceptTop = conceptMoneyRank
	}

	// 4. 全球主要指数
	globalIndexes := newsApi.GetCachedGlobalStockIndexes("common")

	success(c, gin.H{
		"marketStat":        latestStat,
		"industryMoneyRank": industryTop,
		"conceptMoneyRank":  conceptTop,
		"globalIndexes":     globalIndexes,
		"todayStats":        stats,
	})
}

// HandleGetDashboardPortfolio 获取投资组合概览
// GET /api/v1/dashboard/portfolio
func HandleGetDashboardPortfolio(c *gin.Context) {
	cfg := data.GetSettingConfig()
	sdApi := data.NewStockDataApi()
	portfolioApi := data.NewPortfolioApi(cfg.Settings)

	// 获取自选股列表（关注列表）
	followList := sdApi.GetFollowList(0)

	// 收集股票代码
	var codes []string
	for _, st := range *followList {
		codes = append(codes, st.StockCode)
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

	// 获取所有持仓计算盈亏
	allPositions := portfolioApi.GetPositions()
	_ = allPositions // positions come from GetPositionsWithPnL below

	positions := portfolioApi.GetPositionsWithPnL(priceMap)
	cash := portfolioApi.CashAmount()

	// 盈亏汇总
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
