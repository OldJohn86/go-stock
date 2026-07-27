package service

import "go-stock/backend/data"

// TradingService 交易日志(trading record)领域的传输无关服务层。
type TradingService interface {
	// RecordList 分页查询交易记录。
	RecordList(query data.TradingRecordListQuery) (*data.TradingRecordPageData, error)
	// Statistics 交易记录统计。
	Statistics() (*data.TradingRecordStatistics, error)
	// AddRecord 新增交易记录，返回新记录 ID。
	AddRecord(record data.TradingRecord) (uint, error)
	// RecordById 按 ID 获取交易记录。
	RecordById(id uint) (*data.TradingRecord, error)
	// UpdateRecord 更新交易记录。
	UpdateRecord(record data.TradingRecord) error
	// DeleteRecord 删除交易记录。
	DeleteRecord(id uint) error
	// CheckFrequentTrading 判断是否可交易及提示信息。
	CheckFrequentTrading(code string) (bool, string)
}

type tradingService struct{}

// NewTradingService 构造默认实现。构造过程不触碰数据库，可安全用于包级变量。
func NewTradingService() TradingService {
	return &tradingService{}
}

func (s *tradingService) RecordList(query data.TradingRecordListQuery) (*data.TradingRecordPageData, error) {
	return data.NewStockDataApi().GetTradingRecordList(query)
}

func (s *tradingService) Statistics() (*data.TradingRecordStatistics, error) {
	return data.NewStockDataApi().GetTradingRecordStatistics()
}

func (s *tradingService) AddRecord(record data.TradingRecord) (uint, error) {
	return data.NewStockDataApi().AddTradingRecord(record)
}

func (s *tradingService) RecordById(id uint) (*data.TradingRecord, error) {
	return data.NewStockDataApi().GetTradingRecordById(id)
}

func (s *tradingService) UpdateRecord(record data.TradingRecord) error {
	return data.NewStockDataApi().UpdateTradingRecord(record)
}

func (s *tradingService) DeleteRecord(id uint) error {
	return data.NewStockDataApi().DeleteTradingRecord(id)
}

func (s *tradingService) CheckFrequentTrading(code string) (bool, string) {
	return data.NewStockDataApi().CheckFrequentTrading(code)
}
