package data

import (
	"fmt"
	"go-stock/backend/models"
	"time"
)

type RiskApi struct {
	settings *Settings
}

func NewRiskApi(s *Settings) *RiskApi {
	return &RiskApi{settings: s}
}

// CalculateRiskScore 根据持仓数据计算综合风险评分
// trades 参数可选（传 nil 时不检查频繁交易维度）
func (r *RiskApi) CalculateRiskScore(positions []PositionWithPnL, cashPct float64, trades []models.Trade) RiskReport {
	report := RiskReport{
		CashPct: cashPct,
	}
	totalScore := 0

	report.PositionCount = len(positions)

	if len(positions) == 0 {
		report.Level = "low"
		return report
	}

	// 找最大单股仓位和总浮亏
	maxPosPct := 0.0
	totalPnL := 0.0
	totalCost := 0.0
	stopCount := 0
	for _, pos := range positions {
		if pos.PositionPct > maxPosPct {
			maxPosPct = pos.PositionPct
		}
		totalPnL += pos.PnLAmount
		totalCost += pos.CostPrice * float64(pos.Quantity)
		if pos.StopTriggered {
			stopCount++
		}
	}
	report.MaxPosPct = maxPosPct
	if totalCost > 0 {
		report.TotalPnLPct = totalPnL / totalCost * 100
	}

	// 维度 1：仓位集中度
	if maxPosPct > 50 {
		s := 30
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "仓位集中",
			Score:     s,
			Message:   "最大单股仓位超过50%，高度集中风险",
		})
	} else if maxPosPct > r.settings.MaxPositionPct {
		s := 15
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "仓位集中",
			Score:     s,
			Message:   "最大单股仓位超过设定阈值，建议分散",
		})
	}

	// 维度 2：现金比例
	if cashPct < 2 {
		s := 30
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "现金不足",
			Score:     s,
			Message:   "现金比例极低（<2%），无法应对下跌补仓或紧急情况",
		})
	} else if cashPct < r.settings.MinCashPct {
		s := 15
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "现金不足",
			Score:     s,
			Message:   "现金比例低于安全线，建议保留更多现金",
		})
	}

	// 维度 3：止损触发
	if stopCount > 0 {
		s := stopCount * 15
		if s > 30 {
			s = 30
		}
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "止损触发",
			Score:     s,
			Message:   "有持仓已触及止损位，建议及时处理",
		})
	}

	// 维度 4：整体浮亏
	if report.TotalPnLPct < -20 {
		s := 25
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "整体浮亏",
			Score:     s,
			Message:   "总体浮亏超过20%，需重新评估持仓策略",
		})
	} else if report.TotalPnLPct < -10 {
		s := 10
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "整体浮亏",
			Score:     s,
			Message:   "总体浮亏超过10%，注意控制回撤",
		})
	}

	// 维度 5：持仓数量
	posCount := len(positions)
	if posCount == 1 {
		s := 10
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "持仓数量",
			Score:     s,
			Message:   "仅持有1只股票，风险高度集中，建议分散至3-5只",
		})
	} else if posCount >= 5 {
		s := 5
		totalScore += s
		report.Items = append(report.Items, RiskItem{
			Dimension: "持仓数量",
			Score:     s,
			Message:   "持有5只以上股票，注意管理难度增加，建议精简持仓",
		})
	}

	// 维度 6：频繁交易
	if len(trades) > 0 {
		cutoff := time.Now().AddDate(0, 0, -r.settings.FreqTradeDays)
		tradeCount := 0
		for _, t := range trades {
			if t.CreatedAt.After(cutoff) {
				tradeCount++
			}
		}
		report.TradeCount = tradeCount
		limit := r.settings.FreqTradeLimit
		if limit <= 0 {
			limit = 3
		}
		if tradeCount > limit {
			report.HasFreqTrade = true
			s := 15
			totalScore += s
			report.Items = append(report.Items, RiskItem{
				Dimension: "频繁交易",
				Score:     s,
				Message:   fmt.Sprintf("近%d天交易%d次（上限%d次），建议降低交易频率", r.settings.FreqTradeDays, tradeCount, limit),
			})
		}
	}

	if totalScore > 100 {
		totalScore = 100
	}
	report.Score = totalScore

	switch {
	case totalScore >= 70:
		report.Level = "high"
	case totalScore >= 40:
		report.Level = "medium"
	default:
		report.Level = "low"
	}

	return report
}
