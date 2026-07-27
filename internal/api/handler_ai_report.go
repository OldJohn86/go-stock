package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetAIReportList 获取AI研究报告列表
// GET /api/v1/ai-report/list?keyword=&page=1&pageSize=20
func HandleGetAIReportList(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	query := models.AIResponseResultQuery{
		StockCode: c.Query("keyword"),
		StockName: c.Query("keyword"),
		Question:  c.Query("keyword"),
		Page:      page,
		PageSize:  pageSize,
	}
	if query.Page <= 0 {
		query.Page = 1
	}
	if query.PageSize <= 0 || query.PageSize > 100 {
		query.PageSize = 20
	}

	result, err := data.NewAIResponseResultService().GetAIResponseResultList(query)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleDeleteAIReport 删除AI研究报告
// POST /api/v1/ai-report/delete/:id
func HandleDeleteAIReport(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}

	err = data.NewAIResponseResultService().DeleteAIResponseResult(uint(id))
	if err != nil {
		fail(c, "删除失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}
