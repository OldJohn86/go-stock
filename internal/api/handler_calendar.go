package api

import (
	"fmt"
	"time"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// DailyPnLItem 每日盈亏统计项
type DailyPnLItem struct {
	Date       string  `json:"date"`
	BuyAmount  float64 `json:"buyAmount"`
	SellAmount float64 `json:"sellAmount"`
	NetAmount  float64 `json:"netAmount"`
	TradeCount int     `json:"tradeCount"`
}

// HandleGetDailyPnL 获取每日交易盈亏日历热力图数据
// GET /api/v1/trading/daily-pnl?year=2026&month=7
func HandleGetDailyPnL(c *gin.Context) {
	year := c.Query("year")
	month := c.Query("month")
	if year == "" || month == "" {
		fail(c, "参数错误: 需要year和month参数")
		return
	}

	// 计算开始日期（当月第一天）
	startDate := fmt.Sprintf("%s-%s-01", year, month)
	start, err := time.ParseInLocation("2006-1-2", startDate, time.Local)
	if err != nil {
		fail(c, "参数错误: 无效的日期参数")
		return
	}

	// 计算结束日期（当月最后一天）
	end := start.AddDate(0, 1, -1)

	query := data.TradingRecordListQuery{
		StartDate: start.Format("2006-01-02"),
		EndDate:   end.Format("2006-01-02"),
		Page:      1,
		PageSize:  99999, // 一次性获取当月全部记录
	}

	result, err := data.NewStockDataApi().GetTradingRecordList(query)
	if err != nil {
		fail(c, "查询交易记录失败: "+err.Error())
		return
	}

	// 按日期分组统计
	dailyMap := make(map[string]*DailyPnLItem)
	dateOrder := make([]string, 0)

	for _, item := range result.List {
		dateStr := item.TradingTime.Format("2006-01-02")
		if _, ok := dailyMap[dateStr]; !ok {
			dailyMap[dateStr] = &DailyPnLItem{
				Date: dateStr,
			}
			dateOrder = append(dateOrder, dateStr)
		}

		d := dailyMap[dateStr]
		// Amount 是 gorm:"-" 计算字段，需要手动计算
		amount := item.Price * float64(item.Volume)
		if item.Direction == "买入" {
			d.BuyAmount += amount
		} else if item.Direction == "卖出" {
			d.SellAmount += amount
		}
		d.NetAmount = d.SellAmount - d.BuyAmount
		d.TradeCount++
	}

	// 结果按日期升序排列
	items := make([]DailyPnLItem, 0, len(dateOrder))
	for i := len(dateOrder) - 1; i >= 0; i-- {
		items = append(items, *dailyMap[dateOrder[i]])
	}

	success(c, items)
}
