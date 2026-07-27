package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetStockKLineData 获取股票K线数据
// GET /api/v1/stock/:code/kline?type=101&days=100
// type: 101=日K, 102=周K, 103=月K, 5/15/30/60=分钟线
func HandleGetStockKLineData(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}

	kType := c.DefaultQuery("type", "101")
	days, _ := strconv.Atoi(c.DefaultQuery("days", "100"))
	if days <= 0 || days > 500 {
		days = 100
	}

	result := data.FetchKLineWithFallback(code, "", kType, days, "")
	if result != nil && result.Data != nil && len(*result.Data) > 0 {
		success(c, result.Data)
		return
	}

	fail(c, "获取K线数据失败")
}

// HandleGetStockMinuteData 获取分时数据
// GET /api/v1/stock/:code/minute
func HandleGetStockMinuteData(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}

	minData, date := data.NewStockDataApi().GetStockMinutePriceData(code)
	success(c, gin.H{
		"date": date,
		"data": minData,
	})
}

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
// GET /api/v1/stock/list?page=1&pageSize=20&name=&macdGoldenFork=true&kdjGoldenFork=true
func HandleGetAllStocks(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	name := c.Query("name")

	ti := models.TechnicalIndicators{
		MACDGOLDENFORK:     c.Query("macdGoldenFork") == "true",
		KDJGOLDENFORK:      c.Query("kdjGoldenFork") == "true",
		BREAKTHROUGH:       c.Query("breakThrough") == "true",
		LOWFUNDSINFLOW:     c.Query("lowFundsInflow") == "true",
		HIGHFUNDSOUTFLOW:   c.Query("highFundsOutflow") == "true",
		BREAKUPMA5DAYS:     c.Query("breakUpMa5Days") == "true",
		LONGAVGARRAY:       c.Query("longAvgArray") == "true",
		SHORTAVGARRAY:      c.Query("shortAvgArray") == "true",
		UPPERLARGEVOLUME:   c.Query("upperLargeVolume") == "true",
		DOWNNARROWVOLUME:   c.Query("downNarrowVolume") == "true",
		ONEDAYANGLINE:      c.Query("oneDayangLine") == "true",
		TWODAYANGLINES:     c.Query("twoDayangLines") == "true",
		RISESUN:            c.Query("riseSun") == "true",
		POWERFULGUN:        c.Query("powerFulgun") == "true",
		RESTOREJUSTICE:     c.Query("restoreJustice") == "true",
		DOWN7DAYS:          c.Query("down7Days") == "true",
		UPPER8DAYS:         c.Query("upper8Days") == "true",
		UPPER9DAYS:         c.Query("upper9Days") == "true",
		HEAVENRULE:         c.Query("heavenRule") == "true",
		UPSIDEVOLUME:       c.Query("upsideVolume") == "true",
		BEARISHENGULFING:   c.Query("bearishEngulfing") == "true",
		REVERSINGHAMMER:    c.Query("reversingHammer") == "true",
		SHOOTINGSTAR:       c.Query("shootingStar") == "true",
		EVENINGSTAR:        c.Query("eveningStar") == "true",
		FIRSTDAWN:          c.Query("firstDawn") == "true",
		PREGNANT:           c.Query("pregnant") == "true",
		BLACKCLOUDTOPS:     c.Query("blackCloudTops") == "true",
		MORNINGSTAR:        c.Query("morningStar") == "true",
		NARROWFINISH:       c.Query("narrowFinish") == "true",
	}

	uppDays, _ := strconv.Atoi(c.Query("uppDays"))
	ti.UPP_DAYS = uppDays

	concernRank, _ := strconv.Atoi(c.Query("concernRank7Days"))
	ti.CONCERN_RANK_7DAYS = concernRank

	upNday, _ := strconv.Atoi(c.Query("upNday"))
	ti.UPNDAY = upNday

	downNday, _ := strconv.Atoi(c.Query("downNday"))
	ti.DOWNNDAY = downNday

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
