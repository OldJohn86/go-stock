package api

import (
	"context"
	"strconv"

	"go-stock/backend/agent"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetCronTaskList 获取定时任务列表
// GET /api/v1/cron-tasks/list?page=1&pageSize=20&name=&taskType=&status=
func HandleGetCronTaskList(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	name := c.Query("name")
	taskType := c.Query("taskType")
	status := c.Query("status")

	query := &models.CronTaskQuery{
		Page:     page,
		PageSize: pageSize,
		Name:     name,
		TaskType: taskType,
		Status:   status,
	}

	result := agent.NewCronTaskApi().List(query)
	if result == nil {
		success(c, gin.H{
			"total": 0,
			"data":  []models.CronTask{},
		})
		return
	}
	success(c, result)
}

// HandleCreateCronTask 创建定时任务
// POST /api/v1/cron-tasks/create
func HandleCreateCronTask(c *gin.Context) {
	var task models.CronTask
	if err := c.ShouldBindJSON(&task); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err := agent.NewCronTaskApi().Create(&task)
	if err != nil {
		fail(c, "创建失败: "+err.Error())
		return
	}
	success(c, task)
}

// HandleUpdateCronTask 更新定时任务
// POST /api/v1/cron-tasks/update
func HandleUpdateCronTask(c *gin.Context) {
	var task models.CronTask
	if err := c.ShouldBindJSON(&task); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err := agent.NewCronTaskApi().Update(&task)
	if err != nil {
		fail(c, "更新失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}

// HandleDeleteCronTask 删除定时任务
// POST /api/v1/cron-tasks/delete/:id
func HandleDeleteCronTask(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的任务ID")
		return
	}
	err = agent.NewCronTaskApi().Delete(uint(id))
	if err != nil {
		fail(c, "删除失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}

// HandleEnableCronTask 启用/禁用定时任务
// POST /api/v1/cron-tasks/enable/:id
// Body: {"enable": true/false}
func HandleEnableCronTask(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的任务ID")
		return
	}
	var req struct {
		Enable bool `json:"enable"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err = agent.NewCronTaskApi().EnableTask(uint(id), req.Enable)
	if err != nil {
		fail(c, "操作失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "操作成功"})
}

// HandleExecuteCronTaskNow 立即执行定时任务
// POST /api/v1/cron-tasks/execute/:id
func HandleExecuteCronTaskNow(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的任务ID")
		return
	}

	api := agent.NewCronTaskApi()
	task, err := api.GetByID(uint(id))
	if err != nil || task == nil {
		fail(c, "任务不存在")
		return
	}

	go api.ExecuteTask(context.Background(), task)
	success(c, gin.H{"message": "任务已开始执行"})
}

// HandleGetCronTaskTypes 获取任务类型列表
// GET /api/v1/cron-tasks/types
func HandleGetCronTaskTypes(c *gin.Context) {
	types := agent.NewCronTaskApi().GetTaskTypes()
	success(c, types)
}
