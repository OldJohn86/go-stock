package api

import (
	"fmt"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetTradingRecordList 获取交易日志列表
// GET /api/v1/trading/records?keyword=&direction=&startDate=&endDate=&page=1&pageSize=20
func HandleGetTradingRecordList(c *gin.Context) {
	page, _ := parseInt(c.Query("page"), 1)
	pageSize, _ := parseInt(c.Query("pageSize"), 20)
	if pageSize <= 0 || pageSize > 50 {
		pageSize = 20
	}

	query := data.TradingRecordListQuery{
		Keyword:   c.Query("keyword"),
		Direction: c.Query("direction"),
		StartDate: c.Query("startDate"),
		EndDate:   c.Query("endDate"),
		Page:      page,
		PageSize:  pageSize,
	}

	result, err := data.NewStockDataApi().GetTradingRecordList(query)
	if err != nil {
		fail(c, "查询交易日志失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetTradingRecordStatistics 获取交易日志统计数据
// GET /api/v1/trading/statistics
func HandleGetTradingRecordStatistics(c *gin.Context) {
	stats, err := data.NewStockDataApi().GetTradingRecordStatistics()
	if err != nil {
		fail(c, "获取交易统计失败: "+err.Error())
		return
	}
	success(c, stats)
}

// parseInt 辅助：解析整数，失败返回默认值
func parseInt(s string, defaultVal int) (int, error) {
	if s == "" {
		return defaultVal, nil
	}
	var v int
	_, err := fmt.Sscanf(s, "%d", &v)
	if err != nil {
		return defaultVal, err
	}
	return v, nil
}
