package api

import (
	"strconv"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetFundList 获取关注的基金列表（分页）
// GET /api/v1/fund/list?pageIndex=1&pageSize=20&keyword=
func HandleGetFundList(c *gin.Context) {
	pageIndex, _ := strconv.Atoi(c.DefaultQuery("pageIndex", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	keyword := c.Query("keyword")

	result := data.NewFundApi().GetFollowedFundPaged(pageIndex, pageSize, keyword)
	success(c, result)
}

// HandleSearchFunds 搜索基金
// GET /api/v1/fund/search?keyword=
func HandleSearchFunds(c *gin.Context) {
	keyword := c.Query("keyword")
	if keyword == "" {
		badRequest(c, "搜索关键词不能为空")
		return
	}

	result := data.NewFundApi().SearchFundCodes(keyword)
	success(c, result)
}

// HandleFollowFund 关注基金
// POST /api/v1/fund/follow
func HandleFollowFund(c *gin.Context) {
	var req struct {
		Code string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	msg := data.NewFundApi().FollowFund(req.Code)
	success(c, gin.H{"message": msg})
}

// HandleUnfollowFund 取消关注基金
// POST /api/v1/fund/unfollow
func HandleUnfollowFund(c *gin.Context) {
	var req struct {
		Code string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	msg := data.NewFundApi().UnFollowFund(req.Code)
	success(c, gin.H{"message": msg})
}

// HandleGetFundRanking 获取基金排行
// GET /api/v1/fund/ranking?marketType=&fundType=&sortField=&sortOrder=&pageIndex=1&pageSize=20
func HandleGetFundRanking(c *gin.Context) {
	pageIndex, _ := strconv.Atoi(c.DefaultQuery("pageIndex", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	marketType := c.DefaultQuery("marketType", "1")
	fundType := c.DefaultQuery("fundType", "1")
	sortField := c.DefaultQuery("sortField", "yearGrowth")
	sortOrder := c.DefaultQuery("sortOrder", "desc")

	result, err := data.NewFundApi().GetFundRanking(marketType, fundType, sortField, sortOrder, pageIndex, pageSize)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetFundHoldings 获取基金十大持仓
// GET /api/v1/fund/:code/holdings
func HandleGetFundHoldings(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "基金代码不能为空")
		return
	}

	result, err := data.NewFundApi().GetFundTop10Holdings(code)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetFundHistory 获取基金历史净值
// GET /api/v1/fund/:code/history?pageIndex=1&pageSize=20&startDate=&endDate=
func HandleGetFundHistory(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "基金代码不能为空")
		return
	}
	pageIndex, _ := strconv.Atoi(c.DefaultQuery("pageIndex", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	startDate := c.Query("startDate")
	endDate := c.Query("endDate")

	result, err := data.NewFundApi().GetFundHistoryNetValue(code, pageIndex, pageSize, startDate, endDate)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetFundKLine 获取基金K线数据
// GET /api/v1/fund/:code/kline?klt=101&limit=100
func HandleGetFundKLine(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "基金代码不能为空")
		return
	}
	klt := c.DefaultQuery("klt", "101")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))

	result := data.NewFundKLineApi().GetFundKLine(code, klt, limit)
	success(c, result)
}

// HandleGetFundBasic 获取基金基本信息
// GET /api/v1/fund/:code/basic
func HandleGetFundBasic(c *gin.Context) {
	code := c.Param("code")
	if code == "" {
		badRequest(c, "基金代码不能为空")
		return
	}

	result, err := data.NewFundApi().CrawlFundBasic(code)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}
