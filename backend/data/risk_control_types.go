package data

import "go-stock/backend/models"

// PriceInfo 实时股价信息
type PriceInfo struct {
	Current   float64 // 当前价
	PrevClose float64 // 昨收
	High5d    float64 // 近5日最高（可选）
}

// PositionWithPnL 运行时持仓（含实时盈亏，不存 DB）
type PositionWithPnL struct {
	models.Position
	CurrentPrice   float64 `json:"currentPrice"`
	PnLPct         float64 `json:"pnlPct"`
	PnLAmount      float64 `json:"pnlAmount"`
	PositionPct    float64 `json:"positionPct"`
	TodayChangePct float64 `json:"todayChangePct"`
	StopTriggered  bool    `json:"stopTriggered"`
	Concentrated   bool    `json:"concentrated"`
}

// TradeRequest 交易请求
type TradeRequest struct {
	StockCode string  `json:"stockCode"`
	StockName string  `json:"stockName"`
	Type      string  `json:"type"`
	Price     float64 `json:"price"`
	Quantity  int64   `json:"quantity"`
	Notes     string  `json:"notes"`
}

// Warning 纪律警告
type Warning struct {
	Rule    string `json:"rule"`
	Message string `json:"message"`
	Level   string `json:"level"` // "block"|"warn"
}

// DisciplineResult 纪律检查结果
type DisciplineResult struct {
	Blocked  bool      `json:"blocked"`
	Warnings []Warning `json:"warnings"`
}

// RiskItem 单维度风险项
type RiskItem struct {
	Dimension string `json:"dimension"`
	Score     int    `json:"score"`
	Message   string `json:"message"`
}

// RiskReport 风险评估报告
type RiskReport struct {
	Score         int        `json:"score"`
	Level         string     `json:"level"` // "low"|"medium"|"high"
	Items         []RiskItem `json:"items"`
	CashPct       float64    `json:"cashPct"`
	MaxPosPct     float64    `json:"maxPosPct"`
	TotalPnLPct   float64    `json:"totalPnlPct"`
	PositionCount int        `json:"positionCount"`
	TradeCount    int        `json:"tradeCount"`
	HasFreqTrade  bool       `json:"hasFreqTrade"`
}

// RiskPoint AI 结构化输出的风险点
type RiskPoint struct {
	Dimension string `json:"dimension"`
	Severity  string `json:"severity"` // "high"|"medium"|"low"
	Detail    string `json:"detail"`
}

// AIAnalysisOutput AI 结构化输出
type AIAnalysisOutput struct {
	RiskScore   int         `json:"riskScore"`
	Summary     string      `json:"summary"`
	RiskPoints  []RiskPoint `json:"riskPoints"`
	Suggestions []string    `json:"suggestions"`
}

// StockSearchResult 股票搜索返回
type StockSearchResult struct {
	Code string `json:"code"`
	Name string `json:"name"`
}
