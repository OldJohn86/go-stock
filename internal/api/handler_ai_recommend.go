package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetAiRecommendStocksList 获取AI推荐股票列表
// GET /api/v1/ai-recommend/list?keyword=&startDate=&endDate=&page=1&pageSize=20
func HandleGetAiRecommendStocksList(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	query := &models.AiRecommendStocksQuery{
		StockCode: c.Query("keyword"),
		StockName: c.Query("keyword"),
		BkName:    c.Query("keyword"),
		ModelName: c.Query("keyword"),
		StartDate: c.Query("startDate"),
		EndDate:   c.Query("endDate"),
		Page:      page,
		PageSize:  pageSize,
	}
	if query.Page <= 0 {
		query.Page = 1
	}
	if query.PageSize <= 0 || query.PageSize > 100 {
		query.PageSize = 20
	}

	result, err := data.NewAiRecommendStocksService().GetAiRecommendStocksList(query)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleUpdateAiRecommendAlert 更新AI推荐股票的预警状态
// POST /api/v1/ai-recommend/alert
func HandleUpdateAiRecommendAlert(c *gin.Context) {
	var req struct {
		ID          uint `json:"id" binding:"required"`
		EnableAlert bool `json:"enableAlert"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	err := data.NewAiRecommendStocksService().UpdateAiRecommendStocksAlert(req.ID, req.EnableAlert)
	if err != nil {
		fail(c, "操作失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}

// HandleDeleteAiRecommendStock 删除AI推荐股票记录
// POST /api/v1/ai-recommend/delete/:id
func HandleDeleteAiRecommendStock(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}

	err = data.NewAiRecommendStocksService().DeleteAiRecommendStocks(uint(id))
	if err != nil {
		fail(c, "删除失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}
