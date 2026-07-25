package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetStockRealTimePrice 获取单只股票实时行情
// GET /api/v1/stock/real-time/:code
func HandleGetStockRealTimePrice(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}

	api := data.NewStockDataApi()
	// 取用时尝试 App 中的缓存逻辑

	stocks, err := api.GetStockCodeRealTimeData(code)
	if err != nil {
		fail(c, "获取实时行情失败: "+err.Error())
		return
	}
	if stocks == nil || len(*stocks) == 0 {
		fail(c, "未获取到行情数据")
		return
	}

	stock := (*stocks)[0]
	success(c, stock)
}

// HandleGetStockRealTimeBatch 批量获取实时行情
// GET /api/v1/stock/realtime-batch?codes=000001.SZ,600519.SH
func HandleGetStockRealTimeBatch(c *gin.Context) {
	codes := c.QueryArray("codes")
	if len(codes) == 0 {
		// 也支持用逗号分隔传入单个 codes 参数
		raw := c.Query("codes")
		if raw != "" {
			codes = []string{raw}
		}
	}
	if len(codes) == 0 {
		badRequest(c, "请传入股票代码，多个用逗号分隔")
		return
	}

	api := data.NewStockDataApi()
	stocks, err := api.GetStockCodeRealTimeData(codes...)
	if err != nil {
		fail(c, "获取实时行情失败: "+err.Error())
		return
	}
	success(c, stocks)
}

// HandleGetAllStocks 获取全部股票列表（含技术指标筛选）
// GET /api/v1/stock/list?page=1&pageSize=20&name=
func HandleGetAllStocks(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	name := c.Query("name")

	// 解析可选的 technicalIndicators 参数（JSON 字符串）
	var ti models.TechnicalIndicators
	if tiStr := c.Query("technicalIndicators"); tiStr != "" {
		// 简单字段映射（可选）
	}

	api := data.NewStockDataApi()
	result := api.GetAllStocks(page, pageSize, name, ti)
	success(c, result)
}

// HandleGetFollowList 获取自选股列表
// GET /api/v1/follow/list?groupId=0
func HandleGetFollowList(c *gin.Context) {
	groupId, _ := strconv.Atoi(c.DefaultQuery("groupId", "0"))

	api := data.NewStockDataApi()
	list := api.GetFollowList(groupId)
	if list == nil {
		success(c, []interface{}{})
		return
	}
	success(c, list)
}

// HandleFollowStock 关注股票（加入自选）
// POST /api/v1/follow/follow
func HandleFollowStock(c *gin.Context) {
	var req struct {
		StockCode string `json:"stockCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入 stockCode")
		return
	}

	api := data.NewStockDataApi()
	result := api.Follow(req.StockCode)
	success(c, gin.H{"message": result})
}

// HandleUnFollowStock 取消关注
// POST /api/v1/follow/unfollow
func HandleUnFollowStock(c *gin.Context) {
	var req struct {
		StockCode string `json:"stockCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入 stockCode")
		return
	}

	api := data.NewStockDataApi()
	result := api.UnFollow(req.StockCode)
	success(c, gin.H{"message": result})
}

// HandleGetStockLatestFinance 获取 A 股最新财务数据
// GET /api/v1/f10/latest-finance?stockCode=600519
func HandleGetStockLatestFinance(c *gin.Context) {
	code := c.Query("stockCode")
	if code == "" {
		badRequest(c, "请传入 stockCode")
		return
	}

	// 港股自动路由
	if data.IsHKCodeForRoute(code) {
		md := data.NewStockDataApi().GetHKStockLatestFinanceToMarkdown(code)
		success(c, gin.H{"markdown": md})
		return
	}

	md := data.NewStockDataApi().GetStockLatestFinanceToMarkdown(code)
	success(c, gin.H{"markdown": md})
}

// HandleGetHKStockLatestFinance 获取港股最新财务数据
// GET /api/v1/f10/hk-finance?stockCode=00700.HK
func HandleGetHKStockLatestFinance(c *gin.Context) {
	code := c.Query("stockCode")
	if code == "" {
		badRequest(c, "请传入 stockCode")
		return
	}

	md := data.NewStockDataApi().GetHKStockLatestFinanceToMarkdown(code)
	success(c, gin.H{"markdown": md})
}
