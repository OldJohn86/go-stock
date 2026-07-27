package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetBacktestAnalysis 回测分析：基于交易记录计算各项指标
// GET /api/v1/trading/backtest
func HandleGetBacktestAnalysis(c *gin.Context) {
	api := data.NewStockDataApi()

	// 获取所有卖出记录（已平仓）
	sellQuery := data.TradingRecordListQuery{
		Direction: "卖出",
		Page:      1,
		PageSize:  9999,
	}
	sellResult, err := api.GetTradingRecordList(sellQuery)
	if err != nil {
		fail(c, "获取交易记录失败: "+err.Error())
		return
	}

	// 获取所有买入记录
	buyQuery := data.TradingRecordListQuery{
		Direction: "买入",
		Page:      1,
		PageSize:  9999,
	}
	buyResult, err := api.GetTradingRecordList(buyQuery)
	if err != nil {
		fail(c, "获取交易记录失败: "+err.Error())
		return
	}

	// 计算各项指标
	sellRecords := sellResult.List
	buyRecords := buyResult.List

	totalTrades := len(sellRecords)
	winTrades := 0
	loseTrades := 0
	totalProfit := 0.0
	totalLoss := 0.0
	bestTrade := 0.0
	worstTrade := 0.0
	totalFees := 0.0

	for _, r := range sellRecords {
		profit := r.ProfitAmount
		totalFees += r.Fee

		if profit > 0 {
			winTrades++
			totalProfit += profit
			if profit > bestTrade {
				bestTrade = profit
			}
		} else {
			loseTrades++
			totalLoss += profit
			if profit < worstTrade {
				worstTrade = profit
			}
		}
	}

	winRate := 0.0
	if totalTrades > 0 {
		winRate = float64(winTrades) / float64(totalTrades) * 100
	}

	avgProfit := 0.0
	if totalTrades > 0 {
		avgProfit = (totalProfit + totalLoss) / float64(totalTrades)
	}

	// 按股票维度统计
	stockStats := make(map[string]*stockBacktestStat)
	for _, r := range append(sellRecords, buyRecords...) {
		key := r.StockCode
		if _, ok := stockStats[key]; !ok {
			stockStats[key] = &stockBacktestStat{
				StockCode: r.StockCode,
				StockName: r.StockName,
			}
		}
		ss := stockStats[key]
		if r.Direction == "买入" {
			ss.BuyCount++
		} else {
			ss.SellCount++
			ss.TotalProfit += r.ProfitAmount
			if r.ProfitAmount > 0 {
				ss.WinCount++
			}
			if r.ProfitAmount > ss.BestProfit {
				ss.BestProfit = r.ProfitAmount
			}
			if r.ProfitAmount < ss.WorstProfit {
				ss.WorstProfit = r.ProfitAmount
			}
		}
	}

	var stockList []map[string]interface{}
	for _, ss := range stockStats {
		winRate := 0.0
		if ss.SellCount > 0 {
			winRate = float64(ss.WinCount) / float64(ss.SellCount) * 100
		}
		stockList = append(stockList, map[string]interface{}{
			"stockCode":   ss.StockCode,
			"stockName":   ss.StockName,
			"buyCount":    ss.BuyCount,
			"sellCount":   ss.SellCount,
			"totalProfit": ss.TotalProfit,
			"winCount":    ss.WinCount,
			"winRate":     round2(winRate),
			"bestProfit":  ss.BestProfit,
			"worstProfit": ss.WorstProfit,
		})
	}

	// 月度统计
	monthlyMap := make(map[string]*monthlyStat)
	for _, r := range sellRecords {
		monthKey := r.TradingTime.Format("2006-01")
		if _, ok := monthlyMap[monthKey]; !ok {
			monthlyMap[monthKey] = &monthlyStat{Month: monthKey}
		}
		ms := monthlyMap[monthKey]
		ms.TradeCount++
		ms.TotalProfit += r.ProfitAmount
		if r.ProfitAmount > 0 {
			ms.WinCount++
		}
	}

	var monthlyList []map[string]interface{}
	for _, ms := range monthlyMap {
		winRate := 0.0
		if ms.TradeCount > 0 {
			winRate = float64(ms.WinCount) / float64(ms.TradeCount) * 100
		}
		monthlyList = append(monthlyList, map[string]interface{}{
			"month":       ms.Month,
			"tradeCount":  ms.TradeCount,
			"totalProfit": round2(ms.TotalProfit),
			"winCount":    ms.WinCount,
			"winRate":     round2(winRate),
		})
	}

	success(c, gin.H{
		"totalTrades":  totalTrades,
		"winTrades":    winTrades,
		"loseTrades":   loseTrades,
		"winRate":      round2(winRate),
		"totalProfit":  round2(totalProfit + totalLoss),
		"avgProfit":    round2(avgProfit),
		"bestTrade":    round2(bestTrade),
		"worstTrade":   round2(worstTrade),
		"totalFees":    round2(totalFees),
		"stockStats":   stockList,
		"monthlyStats": monthlyList,
	})
}

type stockBacktestStat struct {
	StockCode   string
	StockName   string
	BuyCount    int
	SellCount   int
	TotalProfit float64
	WinCount    int
	BestProfit  float64
	WorstProfit float64
}

type monthlyStat struct {
	Month       string
	TradeCount  int
	TotalProfit float64
	WinCount    int
}

func round2(v float64) float64 {
	return float64(int(v*100)) / 100
}
