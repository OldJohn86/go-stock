package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetDailyOperationPlanList 获取每日操作计划列表
// GET /api/v1/operation-plan/list?stockCode=&stockName=&planDate=&status=&page=1&pageSize=20
func HandleGetDailyOperationPlanList(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))

	query := &models.DailyOperationPlanQuery{
		StockCode: c.Query("stockCode"),
		StockName: c.Query("stockName"),
		PlanDate:  c.Query("planDate"),
		Status:    c.Query("status"),
		Page:      page,
		PageSize:  pageSize,
	}
	if query.Page <= 0 {
		query.Page = 1
	}
	if query.PageSize <= 0 || query.PageSize > 100 {
		query.PageSize = 20
	}

	result, err := data.NewDailyOperationPlanApi().GetDailyOperationPlanList(query)
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, result)
}

// HandleGetDailyOperationPlanByID 根据 ID 获取操作计划详情
// GET /api/v1/operation-plan/:id
func HandleGetDailyOperationPlanByID(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}

	plan, err := data.NewDailyOperationPlanApi().GetDailyOperationPlanByID(uint(id))
	if err != nil {
		fail(c, "查询失败: "+err.Error())
		return
	}
	success(c, plan)
}

// HandleSaveDailyOperationPlan 新增或保存操作计划
// POST /api/v1/operation-plan/save
func HandleSaveDailyOperationPlan(c *gin.Context) {
	var plan models.DailyOperationPlan
	if err := c.ShouldBindJSON(&plan); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	result := data.NewDailyOperationPlanApi().SaveDailyOperationPlan(plan)
	success(c, gin.H{"message": result})
}

// HandleDeleteDailyOperationPlan 删除操作计划
// POST /api/v1/operation-plan/delete/:id
func HandleDeleteDailyOperationPlan(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的 ID")
		return
	}

	result := data.NewDailyOperationPlanApi().DeleteDailyOperationPlan(uint(id))
	success(c, gin.H{"message": result})
}

// HandleUpdateDailyOperationPlanStatus 更新操作计划状态
// POST /api/v1/operation-plan/status
func HandleUpdateDailyOperationPlanStatus(c *gin.Context) {
	var req struct {
		ID     uint   `json:"id" binding:"required"`
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	if err := data.NewDailyOperationPlanApi().UpdateDailyOperationPlanStatus(req.ID, req.Status); err != nil {
		fail(c, "更新失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}
