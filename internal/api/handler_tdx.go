package api

import (
	"strconv"
	"strings"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetTdxMinuteTime 获取TDX分时图数据
// GET /api/v1/tdx/minute-time/:code
func HandleGetTdxMinuteTime(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetMinuteTimeDataAuto(code)
	success(c, result)
}

// HandleGetTdxHistoryMinuteTime 获取历史分时图数据
// GET /api/v1/tdx/history-minute-time/:code?tradeDate=2026-07-24
func HandleGetTdxHistoryMinuteTime(c *gin.Context) {
	code := c.Param("code")
	tradeDate := c.Query("tradeDate")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetHistoryMinuteTimeDataAuto(code, tradeDate)
	success(c, result)
}

// HandleGetTdxTransactions 获取当日分笔成交
// GET /api/v1/tdx/transactions/:code?start=0&count=500
func HandleGetTdxTransactions(c *gin.Context) {
	code := c.Param("code")
	start, _ := strconv.ParseUint(c.DefaultQuery("start", "0"), 10, 32)
	count, _ := strconv.ParseUint(c.DefaultQuery("count", "500"), 10, 32)
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetTransactionDataAuto(code, uint32(start), uint32(count))
	success(c, result)
}

// HandleGetTdxAllTransactions 获取当日全量分笔成交
// GET /api/v1/tdx/all-transactions/:code
func HandleGetTdxAllTransactions(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetAllTransactionDataAuto(code, false)
	success(c, result)
}

// HandleGetTdxHistoryTransactions 获取历史分笔成交
// GET /api/v1/tdx/history-transactions/:code?tradeDate=2026-07-24
func HandleGetTdxHistoryTransactions(c *gin.Context) {
	code := c.Param("code")
	tradeDate := c.Query("tradeDate")
	if code == "" || tradeDate == "" {
		badRequest(c, "股票代码和交易日期不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetHistoryTransactionDataAuto(code, tradeDate, false)
	success(c, result)
}

// HandleGetTdxCallAuction 获取集合竞价数据
// GET /api/v1/tdx/call-auction/:code?start=0&count=500
func HandleGetTdxCallAuction(c *gin.Context) {
	code := c.Param("code")
	start, _ := strconv.ParseUint(c.DefaultQuery("start", "0"), 10, 32)
	count, _ := strconv.ParseUint(c.DefaultQuery("count", "500"), 10, 32)
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetCallAuctionAuto(code, uint32(start), uint32(count))
	success(c, result)
}

// HandleGetTdxCompanyInfo 获取公司概况
// GET /api/v1/tdx/company-info/:code
func HandleGetTdxCompanyInfo(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetF10Data(code)
	success(c, result)
}

// HandleGetTdxFinanceInfo 获取财务数据
// GET /api/v1/tdx/finance-info/:code
func HandleGetTdxFinanceInfo(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetFinanceInfo(code)
	success(c, result)
}

// HandleGetTdxXDXRInfo 获取除权除息信息
// GET /api/v1/tdx/xdxr-info/:code
func HandleGetTdxXDXRInfo(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetXDXRInfo(code)
	success(c, result)
}

// HandleGetTdxCompanyCategoryList 获取公司分类列表
// GET /api/v1/tdx/company-categories/:code
func HandleGetTdxCompanyCategoryList(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetF10CategoryList(code)
	success(c, result)
}

// HandleGetTdxCompanyCategoryContent 获取公司分类内容
// GET /api/v1/tdx/company-category-content/:code?categoryName=
func HandleGetTdxCompanyCategoryContent(c *gin.Context) {
	code := c.Param("code")
	categoryName := c.Query("categoryName")
	if code == "" || categoryName == "" {
		badRequest(c, "股票代码和分类名称不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetF10CategoryContent(code, categoryName)
	success(c, result)
}

// HandleGetTdxSymbolBelongBoard 获取股票所属板块
// GET /api/v1/tdx/symbol-boards/:code
func HandleGetTdxSymbolBelongBoard(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.NewTdxKLineApi().GetMACSymbolBelongBoard(code)
	success(c, result)
}

// HandleGetChipDistribution 获取筹码分布
// GET /api/v1/tdx/chip-distribution/:code?days=365&bins=100&adjustFlag=qfq
func HandleGetChipDistribution(c *gin.Context) {
	code := c.Param("code")
	days, _ := strconv.Atoi(c.DefaultQuery("days", "365"))
	bins, _ := strconv.Atoi(c.DefaultQuery("bins", "100"))
	adjustFlag := c.DefaultQuery("adjustFlag", "qfq")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
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
	if !api.ValidateStockCode(code) {
		fail(c, "股票代码无效: "+code)
		return
	}

	var kLines *[]data.KLineData
	if adjustFlag != "" {
		kLines = api.GetKLineData(code, "101", adjustFlag, days)
	} else {
		result := data.FetchKLineWithFallback(code, "", "101", days, "")
		if result != nil && result.Data != nil {
			kLines = result.Data
		}
	}

	if kLines == nil || len(*kLines) == 0 {
		fail(c, "未获取到K线数据")
		return
	}
	calculator := data.NewChipDistributionCalculator()
	r, err := calculator.Calculate(code, *kLines, bins)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, r)
}

// HandleGetEastMoneyKLine 获取东方财富多周期K线
// GET /api/v1/tdx/kline/:code?klt=101&limit=500
func HandleGetEastMoneyKLine(c *gin.Context) {
	code := c.Param("code")
	klt := c.DefaultQuery("klt", "101")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "500"))
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	api := data.NewEastMoneyKLineApi(data.GetSettingConfig())
	result := api.GetKLineDataBefore(code, klt, "", limit, "")
	success(c, result)
}

// HandleGetKLineWithFallback 获取K线（多数据源自动切换）
// GET /api/v1/tdx/kline-fallback/:code?klt=101&limit=500&adjustFlag=qfq
func HandleGetKLineWithFallback(c *gin.Context) {
	code := c.Param("code")
	klt := c.DefaultQuery("klt", "101")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "500"))
	adjustFlag := c.DefaultQuery("adjustFlag", "qfq")
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	result := data.FetchKLineWithFallback(code, "", klt, limit, "", adjustFlag)
	success(c, result)
}
