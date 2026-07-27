package api

import (
	"encoding/csv"
	"fmt"
	"strconv"
	"time"

	"go-stock/backend/data"
	"go-stock/backend/service"

	"github.com/gin-gonic/gin"
)

// tradingSvc 交易日志的统一服务入口（与 goldstock 合并后的服务层）
var tradingSvc = service.NewTradingService()

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

// HandleSaveTradingRecord 新增/更新交易记录
// POST /api/v1/trading/save
func HandleSaveTradingRecord(c *gin.Context) {
	var req struct {
		ID              uint    `json:"id"`
		StockCode       string  `json:"stockCode" binding:"required"`
		StockName       string  `json:"stockName" binding:"required"`
		Direction       string  `json:"direction" binding:"required"` // 买入/卖出
		Price           float64 `json:"price" binding:"required"`
		Volume          int64   `json:"volume" binding:"required"`
		Fee             float64 `json:"fee"`
		StopLossPrice   float64 `json:"stopLossPrice"`
		TakeProfitPrice float64 `json:"takeProfitPrice"`
		MarketValue     float64 `json:"marketValue"`
		Reason          string  `json:"reason"`
		Mindset         string  `json:"mindset"`
		TradingTime     string  `json:"tradingTime"` // yyyy-MM-dd HH:mm:ss
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	record := data.TradingRecord{
		StockCode:       req.StockCode,
		StockName:       req.StockName,
		Direction:       req.Direction,
		Price:           req.Price,
		Volume:          req.Volume,
		Fee:             req.Fee,
		StopLossPrice:   req.StopLossPrice,
		TakeProfitPrice: req.TakeProfitPrice,
		MarketValue:     req.MarketValue,
		Reason:          req.Reason,
		Mindset:         req.Mindset,
	}

	// 解析交易时间
	if req.TradingTime != "" {
		t, err := time.ParseInLocation("2006-01-02 15:04:05", req.TradingTime, time.Local)
		if err == nil {
			record.TradingTime = t
		}
	}

	api := data.NewStockDataApi()
	var err error
	if req.ID > 0 {
		record.ID = req.ID
		err = api.UpdateTradingRecord(record)
	} else {
		_, err = api.AddTradingRecord(record)
	}
	if err != nil {
		fail(c, "保存交易记录失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "保存成功"})
}

// HandleDeleteTradingRecord 删除交易记录
// POST /api/v1/trading/delete/:id
func HandleDeleteTradingRecord(c *gin.Context) {
	id, _ := parseInt(c.Param("id"), 0)
	if id <= 0 {
		badRequest(c, "无效的记录ID")
		return
	}

	err := data.NewStockDataApi().DeleteTradingRecord(uint(id))
	if err != nil {
		fail(c, "删除交易记录失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}

// HandleExportTradingRecords 导出交易记录 CSV
// GET /api/v1/trading/export
func HandleExportTradingRecords(c *gin.Context) {
	query := data.TradingRecordListQuery{
		Keyword:   c.Query("keyword"),
		Direction: c.Query("direction"),
		StartDate: c.Query("startDate"),
		EndDate:   c.Query("endDate"),
		Page:      1,
		PageSize:  9999, // 一次性导出所有
	}

	result, err := data.NewStockDataApi().GetTradingRecordList(query)
	if err != nil {
		fail(c, "导出失败: "+err.Error())
		return
	}

	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Header("Content-Disposition", fmt.Sprintf(
		`attachment; filename="trading_records_%s.csv"`,
		time.Now().Format("20060102"),
	))

	// 写入 BOM 使 Excel 正确识别 UTF-8
	c.Writer.Write([]byte{0xEF, 0xBB, 0xBF})

	writer := csv.NewWriter(c.Writer)
	writer.Write([]string{"ID", "股票代码", "股票名称", "方向", "价格", "数量", "金额", "交易时间", "手续费", "原因", "止损价", "止盈价"})

	for _, item := range result.List {
		writer.Write([]string{
			fmt.Sprintf("%d", item.TradingRecord.ID),
			item.StockCode,
			item.StockName,
			item.Direction,
			fmt.Sprintf("%.2f", item.Price),
			fmt.Sprintf("%d", item.Volume),
			fmt.Sprintf("%.2f", item.Amount),
			item.TradingTime.Format("2006-01-02 15:04:05"),
			fmt.Sprintf("%.2f", item.Fee),
			item.Reason,
			fmt.Sprintf("%.2f", item.StopLossPrice),
			fmt.Sprintf("%.2f", item.TakeProfitPrice),
		})
	}
	writer.Flush()
}

// HandleCreateTradingRecord 新增交易日志
// POST /api/v1/trading/records
func HandleCreateTradingRecord(c *gin.Context) {
	var record data.TradingRecord
	if err := c.ShouldBindJSON(&record); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	id, err := tradingSvc.AddRecord(record)
	if err != nil {
		fail(c, "新增交易日志失败: "+err.Error())
		return
	}
	success(c, gin.H{"id": id})
}

// HandleGetTradingRecordById 根据 ID 获取单条交易日志
// GET /api/v1/trading/records/:id
func HandleGetTradingRecordById(c *gin.Context) {
	id, err := parseUintParam(c.Param("id"))
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}
	record, err := tradingSvc.RecordById(id)
	if err != nil {
		fail(c, "查询交易日志失败: "+err.Error())
		return
	}
	success(c, record)
}

// HandleUpdateTradingRecord 更新交易日志
// PUT /api/v1/trading/records/:id
func HandleUpdateTradingRecord(c *gin.Context) {
	id, err := parseUintParam(c.Param("id"))
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}
	var record data.TradingRecord
	if err := c.ShouldBindJSON(&record); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	record.ID = id
	if err := tradingSvc.UpdateRecord(record); err != nil {
		fail(c, "更新交易日志失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}

// HandleCheckFrequentTrading 检查是否频繁交易
// GET /api/v1/trading/frequent-check?code=
func HandleCheckFrequentTrading(c *gin.Context) {
	canTrade, msg := tradingSvc.CheckFrequentTrading(c.Query("code"))
	success(c, gin.H{"canTrade": canTrade, "msg": msg})
}

// parseUintParam 解析路径中的无符号整型 ID
func parseUintParam(s string) (uint, error) {
	v, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(v), nil
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
