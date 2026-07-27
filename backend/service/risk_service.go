package service

import (
	"go-stock/backend/data"
	"go-stock/backend/db"
	"go-stock/backend/models"

	"github.com/duke-git/lancet/v2/convertor"
)

// RiskService 风控/持仓/交易领域的传输无关服务层。
// 与 MarketService 一致，对外暴露统一接口，屏蔽底层 PortfolioApi/TradeApi/RiskApi 的组装细节，
// 供 Wails、Gin REST 等不同传输层复用。
type RiskService interface {
	Portfolio() []data.PositionWithPnL
	AddPosition(pos models.Position) error
	UpdatePosition(pos models.Position) error
	DeletePosition(id uint) error
	RiskReport() data.RiskReport
	CheckDiscipline(req data.TradeRequest) data.DisciplineResult
	AddTrade(trade models.Trade) error
	RecentTrades(stockCode string) []models.Trade
	RunRiskAnalysis(onToken func(string)) (models.AIAnalysis, error)
	LastRiskAnalysis() models.AIAnalysis
}

type riskService struct {
	market MarketService
}

// NewRiskService 构造风控服务，价格通过 MarketService 统一获取。
func NewRiskService() RiskService {
	return &riskService{market: NewMarketService()}
}

// prices 获取当前所有持仓股票的实时价格（直连 DB 取持仓，价格走统一行情服务）。
func (s *riskService) prices() map[string]data.PriceInfo {
	result := make(map[string]data.PriceInfo)
	positions := []models.Position{}
	// 直接从 DB 读持仓，避免对 settings 的循环依赖
	db.Dao.Model(&models.Position{}).Find(&positions)
	if len(positions) == 0 {
		return result
	}
	codes := make([]string, 0, len(positions))
	for _, p := range positions {
		codes = append(codes, p.StockCode)
	}
	stockData, err := s.market.RealTimeQuotes(codes...)
	if err != nil || stockData == nil {
		return result
	}
	for _, item := range *stockData {
		price, _ := convertor.ToFloat(item.Price)
		preClose, _ := convertor.ToFloat(item.PreClose)
		result[item.Code] = data.PriceInfo{
			Current:   price,
			PrevClose: preClose,
		}
	}
	return result
}

func (s *riskService) Portfolio() []data.PositionWithPnL {
	cfg := data.GetSettingConfig()
	return data.NewPortfolioApi(cfg.Settings).GetPositionsWithPnL(s.prices())
}

func (s *riskService) AddPosition(pos models.Position) error {
	cfg := data.GetSettingConfig()
	return data.NewPortfolioApi(cfg.Settings).AddPosition(pos)
}

func (s *riskService) UpdatePosition(pos models.Position) error {
	cfg := data.GetSettingConfig()
	return data.NewPortfolioApi(cfg.Settings).UpdatePosition(pos)
}

func (s *riskService) DeletePosition(id uint) error {
	cfg := data.GetSettingConfig()
	return data.NewPortfolioApi(cfg.Settings).DeletePosition(id)
}

func (s *riskService) RiskReport() data.RiskReport {
	cfg := data.GetSettingConfig()
	portfolioApi := data.NewPortfolioApi(cfg.Settings)
	positions := portfolioApi.GetPositionsWithPnL(s.prices())
	cashPct := s.cashPct(cfg, portfolioApi)
	recentTrades := data.NewTradeApi(cfg.Settings).GetRecentTrades("", 30)
	return data.NewRiskApi(cfg.Settings).CalculateRiskScore(positions, cashPct, recentTrades)
}

func (s *riskService) CheckDiscipline(req data.TradeRequest) data.DisciplineResult {
	cfg := data.GetSettingConfig()
	positions := data.NewPortfolioApi(cfg.Settings).GetPositions()
	return data.NewTradeApi(cfg.Settings).CheckDiscipline(req, positions, s.prices())
}

func (s *riskService) AddTrade(trade models.Trade) error {
	cfg := data.GetSettingConfig()
	if err := data.NewTradeApi(cfg.Settings).AddTrade(trade); err != nil {
		return err
	}
	if trade.Type == "sell" {
		return s.applySellToPosition(cfg.Settings, trade)
	}
	return nil
}

// applySellToPosition 卖出后自动扣减/清空对应持仓。
func (s *riskService) applySellToPosition(settings *data.Settings, trade models.Trade) error {
	portfolioApi := data.NewPortfolioApi(settings)
	for _, pos := range portfolioApi.GetPositions() {
		if pos.StockCode != trade.StockCode {
			continue
		}
		newQty := pos.Quantity - trade.Quantity
		if newQty <= 0 {
			return portfolioApi.DeletePosition(pos.ID)
		}
		pos.Quantity = newQty
		return portfolioApi.UpdatePosition(pos)
	}
	return nil
}

func (s *riskService) RecentTrades(stockCode string) []models.Trade {
	cfg := data.GetSettingConfig()
	return data.NewTradeApi(cfg.Settings).GetRecentTrades(stockCode, 30)
}

// RunRiskAnalysis 执行 AI 风控分析。onToken 用于流式回传（REST 场景可传 nil）。
func (s *riskService) RunRiskAnalysis(onToken func(string)) (models.AIAnalysis, error) {
	cfg := data.GetSettingConfig()
	portfolioApi := data.NewPortfolioApi(cfg.Settings)
	positions := portfolioApi.GetPositionsWithPnL(s.prices())
	cashPct := s.cashPct(cfg, portfolioApi)
	recentTrades := data.NewTradeApi(cfg.Settings).GetRecentTrades("", 30)
	riskReport := data.NewRiskApi(cfg.Settings).CalculateRiskScore(positions, cashPct, recentTrades)
	if onToken == nil {
		onToken = func(string) {}
	}
	return data.NewRiskAIApi(cfg.Settings).RunAnalysis(positions, recentTrades, riskReport, "manual", onToken)
}

func (s *riskService) LastRiskAnalysis() models.AIAnalysis {
	cfg := data.GetSettingConfig()
	return data.NewRiskAIApi(cfg.Settings).GetLastAnalysis()
}

// cashPct 计算现金占总资金的百分比。
func (s *riskService) cashPct(cfg *data.SettingConfig, portfolioApi *data.PortfolioApi) float64 {
	if cfg.Settings.TotalCapital <= 0 {
		return 0
	}
	return portfolioApi.CashAmount() / cfg.Settings.TotalCapital * 100
}
