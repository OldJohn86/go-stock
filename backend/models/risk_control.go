package models

import (
	"gorm.io/gorm"
)

// Position 持仓记录
type Position struct {
	gorm.Model
	StockCode     string  `json:"stockCode" gorm:"uniqueIndex;size:20"`
	StockName     string  `json:"stockName" gorm:"size:50"`
	CostPrice     float64 `json:"costPrice"`
	Quantity      int64   `json:"quantity"`
	StopLossPct   float64 `json:"stopLossPct"`   // 默认 -8.0（%），负数
	StopLossPrice float64 `json:"stopLossPrice"` // 绝对止损价，0 表示用 StopLossPct 计算
	Notes         string  `json:"notes" gorm:"type:text"`
}

func (Position) TableName() string {
	return "positions"
}

// Trade 交易记录
type Trade struct {
	gorm.Model
	StockCode string    `json:"stockCode" gorm:"index;size:20"`
	StockName string    `json:"stockName" gorm:"size:50"`
	Type      string    `json:"type" gorm:"size:4"` // "buy" | "sell"
	Price     float64   `json:"price"`
	Quantity  int64     `json:"quantity"`
	TradeDate string `json:"tradeDate" gorm:"size:10"` // YYYY-MM-DD
	Notes     string    `json:"notes" gorm:"type:text"`
	Flagged   bool      `json:"flagged"`
}

func (Trade) TableName() string {
	return "trades"
}

// AIAnalysis AI 风控分析缓存
type AIAnalysis struct {
	gorm.Model
	RiskScore   int    `json:"riskScore"`              // 0-100
	Content     string `json:"content" gorm:"type:text"` // 结构化 JSON 或纯文本
	ContentType string `json:"contentType" gorm:"size:20"` // "structured" | "plain"
	Trigger     string `json:"trigger" gorm:"size:20"`  // "manual" | "auto"
}

func (AIAnalysis) TableName() string {
	return "ai_analyses"
}
