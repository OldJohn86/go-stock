// Package service 提供传输无关的业务服务层，位于 transport(Wails/Gin/AI工具)与 data 数据层之间。
// 各 transport 依赖此处的服务接口而非直接调用 data 包函数，从而实现"通过统一接口进行信息交换"，
// 便于替换实现、注入 mock 以及集中处理缓存等横切逻辑。
package service

import (
	"fmt"
	"strings"

	"go-stock/backend/data"

	"github.com/duke-git/lancet/v2/convertor"
)

// KLineQuery 是查询 K 线的传输无关入参。
type KLineQuery struct {
	Code       string // 证券代码
	Name       string // 证券名称（可选，部分数据源用于日志/兜底）
	Type       string // K线类型：101日/102周/103月/5/15/30/60分钟
	Limit      int    // 拉取条数
	End        string // 截止日期(yyyyMMdd)，空串表示至今
	AdjustFlag string // 复权标识：qfq/hfq/none/0，空串保留各源默认
}

// MarketService 是行情与 K 线的统一服务接口，供各 transport 层依赖，
// 与具体数据源（data 包内的 KLineSource / QuoteSource 降级链/分区路由）解耦。
type MarketService interface {
	// KLine 按降级链获取 K 线数据。
	KLine(q KLineQuery) *data.KLineSourceResult
	// RealTimeQuotes 批量获取实时行情。
	RealTimeQuotes(codes ...string) (*[]data.StockInfo, error)
	// RealTimePrice 获取单只股票的实时价格摘要(含名称/昨收/涨跌幅)，失败返回 code=-1 的错误结构。
	RealTimePrice(stockCode string) map[string]any
	// DayKLine 获取日 K 线（港股优先 gotdx MAC，失败降级至 HK 行情接口）。
	DayKLine(stockCode, stockName string, days int64) *[]data.KLineData
	// CommonKLine 获取通用日 K 线。
	CommonKLine(stockCode, stockName string, days int64) *[]data.KLineData
	// EastMoneyKLinePage 东方财富多周期 K 线分页拉取（含 limit/klt/end 归一）。
	EastMoneyKLinePage(stockCode, stockName, klt string, limit int, end string) *[]data.KLineData
	// ChipDistribution 计算筹码分布（含入参校验与降级链取数）。
	ChipDistribution(stockCode string, days, bins int, adjustFlag string) (*data.ChipDistributionResult, error)
}

// marketService 是 MarketService 的默认实现，委托给 data 包的统一数据源入口。
//
// 注意：此处不在构造时持有 *data.StockDataApi。data.NewStockDataApi() 会读取
// settings（依赖 db.Dao），而各 transport 通常以包级变量方式持有本服务
// （如 var marketSvc = service.NewMarketService()），其初始化早于 main() 中的
// db.Init()。因此改为按请求惰性构造，既避免包初始化期空指针，又与原先各处
// "每次请求 data.NewStockDataApi()" 的行为保持一致。
type marketService struct{}

// NewMarketService 构造默认的 MarketService 实现。构造过程不触碰数据库，可安全用于包级变量。
func NewMarketService() MarketService {
	return &marketService{}
}

func (s *marketService) KLine(q KLineQuery) *data.KLineSourceResult {
	return data.FetchKLineWithFallback(q.Code, q.Name, q.Type, q.Limit, q.End, q.AdjustFlag)
}

func (s *marketService) RealTimeQuotes(codes ...string) (*[]data.StockInfo, error) {
	return data.NewStockDataApi().GetStockCodeRealTimeData(codes...)
}

func (s *marketService) RealTimePrice(stockCode string) map[string]any {
	stockDatas, err := data.NewStockDataApi().GetStockCodeRealTimeData(stockCode)
	if err != nil || stockDatas == nil || len(*stockDatas) == 0 {
		return map[string]any{
			"code":    -1,
			"message": "获取股票价格失败",
			"price":   0,
		}
	}
	stock := (*stockDatas)[0]
	price, _ := convertor.ToFloat(stock.Price)
	if price == 0 {
		price, _ = convertor.ToFloat(stock.A1P)
	}
	if price == 0 {
		price, _ = convertor.ToFloat(stock.B1P)
	}
	if price == 0 {
		price, _ = convertor.ToFloat(stock.PreClose)
	}
	preClose, _ := convertor.ToFloat(stock.PreClose)
	changePercent := 0.0
	if preClose > 0 {
		changePercent = (price - preClose) / preClose * 100
	}
	return map[string]any{
		"code":          0,
		"message":       "success",
		"price":         price,
		"name":          stock.Name,
		"preClose":      preClose,
		"changePercent": changePercent,
	}
}

func (s *marketService) DayKLine(stockCode, stockName string, days int64) *[]data.KLineData {
	// 港股优先使用 gotdx (通达信 ExKLine2) 获取日K线，失败再降级到腾讯接口
	if data.IsHKStockCode(stockCode) {
		tdxData := data.NewTdxKLineApi().GetMACKLineData(stockCode, "101", int(days))
		if tdxData != nil && len(*tdxData) > 0 {
			return tdxData
		}
	}
	return data.NewStockDataApi().GetHK_KLineData(stockCode, "day", days)
}

func (s *marketService) CommonKLine(stockCode, stockName string, days int64) *[]data.KLineData {
	return data.NewStockDataApi().GetCommonKLineData(stockCode, "day", days)
}

func (s *marketService) EastMoneyKLinePage(stockCode, stockName, klt string, limit int, end string) *[]data.KLineData {
	if limit <= 0 {
		limit = 500
	}
	if limit > 5000 {
		limit = 5000
	}
	klt = strings.TrimSpace(klt)
	if klt == "" {
		klt = "1"
	}
	api := data.NewEastMoneyKLineApi(data.GetSettingConfig())
	end = strings.TrimSpace(end)
	return api.GetKLineDataBefore(stockCode, klt, "", limit, end)
}

func (s *marketService) ChipDistribution(stockCode string, days, bins int, adjustFlag string) (*data.ChipDistributionResult, error) {
	stockCode = strings.TrimSpace(stockCode)
	if stockCode == "" {
		return nil, fmt.Errorf("stockCode 不能为空")
	}
	if days <= 0 {
		days = 120
	}
	if bins <= 0 {
		bins = 80
	}
	adjustFlag = strings.TrimSpace(strings.ToLower(adjustFlag))
	if adjustFlag != "" && adjustFlag != "qfq" && adjustFlag != "hfq" {
		adjustFlag = "qfq"
	}

	api := data.NewEastMoneyKLineApi(data.GetSettingConfig())
	if !api.ValidateStockCode(stockCode) {
		return nil, fmt.Errorf("股票代码无效：%s", stockCode)
	}

	var kLines *[]data.KLineData

	if adjustFlag != "" {
		kLines = api.GetKLineData(stockCode, "101", adjustFlag, days)
	} else {
		result := s.KLine(KLineQuery{Code: stockCode, Type: "101", Limit: days})
		if result != nil && result.Data != nil {
			kLines = result.Data
		}
	}

	if kLines == nil || len(*kLines) == 0 {
		return nil, fmt.Errorf("未获取到K线数据")
	}
	calculator := data.NewChipDistributionCalculator()
	return calculator.Calculate(stockCode, *kLines, bins)
}
