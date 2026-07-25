package data

import (
	"fmt"
	"go-stock/backend/db"
	"go-stock/backend/models"
	"time"
)

type TradeApi struct {
	settings *Settings
}

func NewTradeApi(s *Settings) *TradeApi {
	return &TradeApi{settings: s}
}

// CheckDiscipline 检查纪律规则，返回拦截/警告列表
func (t *TradeApi) CheckDiscipline(req TradeRequest, positions []models.Position, prices map[string]PriceInfo) DisciplineResult {
	result := DisciplineResult{}

	if req.Type != "buy" {
		return result // 卖出操作不做追涨/满仓检查
	}

	// Rule 1: 追涨劝阻 — 买入价 > 近5日最高价 × (1 + ChaseBuyPct/100)
	high5d := t.fetchRecentHigh(req.StockCode, prices)
	if high5d > 0 {
		threshold := high5d * (1 + t.settings.ChaseBuyPct/100)
		if req.Price > threshold {
			result.Warnings = append(result.Warnings, Warning{
				Rule: "chase",
				Message: fmt.Sprintf(
					"当前买入价 %.2f 高于近5日最高价 %.2f 的 %.0f%% 阈值（%.2f），存在追涨风险",
					req.Price, high5d, t.settings.ChaseBuyPct, threshold,
				),
				Level: "warn",
			})
		}
	}

	// Rule 2: 满仓拦截 — 买入后现金 < MinCashPct × TotalCapital
	investedAfter := t.currentInvested(positions) + req.Price*float64(req.Quantity)
	cashAfter := t.settings.TotalCapital - investedAfter
	minCash := t.settings.TotalCapital * t.settings.MinCashPct / 100
	if cashAfter < minCash {
		result.Blocked = true
		result.Warnings = append(result.Warnings, Warning{
			Rule: "full_position",
			Message: fmt.Sprintf(
				"买入后现金仅剩 %.0f 元（占 %.1f%%），低于最低现金比例 %.0f%%，已拦截",
				cashAfter, cashAfter/t.settings.TotalCapital*100, t.settings.MinCashPct,
			),
			Level: "block",
		})
	}

	// Rule 3: 频繁交易提醒 — 该股近 N 天内交易次数 ≥ FreqTradeLimit
	recentCount := t.recentTradeCount(req.StockCode, t.settings.FreqTradeDays)
	if recentCount >= t.settings.FreqTradeLimit {
		result.Warnings = append(result.Warnings, Warning{
			Rule: "freq_trade",
			Message: fmt.Sprintf(
				"该股近 %d 天内已操作 %d 次（上限 %d 次），频繁交易会侵蚀收益",
				t.settings.FreqTradeDays, recentCount, t.settings.FreqTradeLimit,
			),
			Level: "warn",
		})
	}

	return result
}

func (t *TradeApi) AddTrade(trade models.Trade) error {
	if trade.TradeDate == "" {
		trade.TradeDate = time.Now().Format("2006-01-02")
	}
	return db.Dao.Create(&trade).Error
}

func (t *TradeApi) GetRecentTrades(stockCode string, days int) []models.Trade {
	var trades []models.Trade
	since := time.Now().AddDate(0, 0, -days).Format("2006-01-02")
	q := db.Dao.Where("trade_date >= ?", since).Order("trade_date desc")
	if stockCode != "" {
		q = q.Where("stock_code = ?", stockCode)
	}
	q.Find(&trades)
	return trades
}

// fetchRecentHigh 从最近交易记录推算近5日最高成交价
func (t *TradeApi) fetchRecentHigh(stockCode string, prices map[string]PriceInfo) float64 {
	if info, ok := prices[stockCode]; ok && info.High5d > 0 {
		return info.High5d
	}
	if info, ok := prices[stockCode]; ok {
		return info.Current
	}
	var trades []models.Trade
	since := time.Now().AddDate(0, 0, -5).Format("2006-01-02")
	db.Dao.Where("stock_code = ? AND trade_date >= ?", stockCode, since).Find(&trades)
	if len(trades) == 0 {
		return 0
	}
	high := 0.0
	for _, tr := range trades {
		if tr.Price > high {
			high = tr.Price
		}
	}
	return high
}

func (t *TradeApi) recentTradeCount(stockCode string, days int) int {
	var count int64
	since := time.Now().AddDate(0, 0, -days).Format("2006-01-02")
	db.Dao.Model(&models.Trade{}).
		Where("stock_code = ? AND trade_date >= ?", stockCode, since).
		Count(&count)
	return int(count)
}

func (t *TradeApi) currentInvested(positions []models.Position) float64 {
	total := 0.0
	for _, pos := range positions {
		total += pos.CostPrice * float64(pos.Quantity)
	}
	return total
}
