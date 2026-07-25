package data

import (
	"go-stock/backend/db"
	"go-stock/backend/models"
)

type PortfolioApi struct {
	settings *Settings
}

func NewPortfolioApi(s *Settings) *PortfolioApi {
	return &PortfolioApi{settings: s}
}

func (p *PortfolioApi) GetPositions() []models.Position {
	var positions []models.Position
	db.Dao.Order("created_at desc").Find(&positions)
	return positions
}

func (p *PortfolioApi) AddPosition(pos models.Position) error {
	if pos.StopLossPct == 0 {
		pos.StopLossPct = p.settings.DefaultStopLossPct
	}
	return db.Dao.Create(&pos).Error
}

func (p *PortfolioApi) UpdatePosition(pos models.Position) error {
	return db.Dao.Save(&pos).Error
}

func (p *PortfolioApi) DeletePosition(id uint) error {
	return db.Dao.Delete(&models.Position{}, id).Error
}

// GetPositionsWithPnL 计算实时盈亏和仓位占比
func (p *PortfolioApi) GetPositionsWithPnL(prices map[string]PriceInfo) []PositionWithPnL {
	positions := p.GetPositions()

	// 计算总持仓市值
	totalMarketValue := 0.0
	for _, pos := range positions {
		current := pos.CostPrice
		if info, ok := prices[pos.StockCode]; ok {
			current = info.Current
		}
		totalMarketValue += current * float64(pos.Quantity)
	}
	totalAssets := p.settings.TotalCapital + totalMarketValue - p.investedCapital(positions)

	result := make([]PositionWithPnL, 0, len(positions))
	for _, pos := range positions {
		current := pos.CostPrice
		prevClose := 0.0
		if info, ok := prices[pos.StockCode]; ok {
			current = info.Current
			prevClose = info.PrevClose
		}

		marketValue := current * float64(pos.Quantity)
		pnlPct := 0.0
		if pos.CostPrice > 0 {
			pnlPct = (current - pos.CostPrice) / pos.CostPrice * 100
		}
		todayChangePct := 0.0
		if prevClose > 0 {
			todayChangePct = (current - prevClose) / prevClose * 100
		}

		positionPct := 0.0
		if totalAssets > 0 {
			positionPct = marketValue / totalAssets * 100
		}

		// 止损判断
		stopTriggered := false
		if pos.StopLossPrice > 0 {
			stopTriggered = current <= pos.StopLossPrice
		} else if pos.StopLossPct != 0 {
			stopTriggered = pnlPct <= pos.StopLossPct
		}

		result = append(result, PositionWithPnL{
			Position:       pos,
			CurrentPrice:   current,
			PnLPct:         pnlPct,
			PnLAmount:      (current - pos.CostPrice) * float64(pos.Quantity),
			PositionPct:    positionPct,
			TodayChangePct: todayChangePct,
			StopTriggered:  stopTriggered,
			Concentrated:   positionPct > p.settings.MaxPositionPct,
		})
	}
	return result
}

// CashAmount 计算剩余现金（总资金 - 建仓成本）
func (p *PortfolioApi) CashAmount() float64 {
	positions := p.GetPositions()
	invested := p.investedCapital(positions)
	cash := p.settings.TotalCapital - invested
	if cash < 0 {
		return 0
	}
	return cash
}

// investedCapital 返回建仓成本（用成本价，不随行情变化）
func (p *PortfolioApi) investedCapital(positions []models.Position) float64 {
	total := 0.0
	for _, pos := range positions {
		total += pos.CostPrice * float64(pos.Quantity)
	}
	return total
}
