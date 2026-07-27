package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetAlarmSetting 获取股票的预警设置
// GET /api/v1/alert/setting/:stockCode
func HandleGetAlarmSetting(c *gin.Context) {
	stockCode := c.Param("stockCode")
	if stockCode == "" {
		badRequest(c, "股票代码不能为空")
		return
	}

	api := data.NewStockDataApi()
	setting, err := api.GetAlarmSetting(stockCode)
	if err != nil {
		fail(c, "获取预警设置失败: "+err.Error())
		return
	}
	if setting == nil {
		// 默认返回空的预警设置
		success(c, gin.H{
			"alarmChangePercent": 0,
			"alarmPrice":         0,
		})
		return
	}
	success(c, gin.H{
		"alarmChangePercent": setting.AlarmChangePercent,
		"alarmPrice":         setting.AlarmPrice,
	})
}

// HandleSetAlarmSetting 设置股票预警
// POST /api/v1/alert/setting
func HandleSetAlarmSetting(c *gin.Context) {
	var req struct {
		StockCode          string  `json:"stockCode" binding:"required"`
		AlarmChangePercent float64 `json:"alarmChangePercent"`
		AlarmPrice         float64 `json:"alarmPrice"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	api := data.NewStockDataApi()
	msg := api.SetAlarmChangePercent(req.AlarmChangePercent, req.AlarmPrice, req.StockCode)
	if msg == "设置失败" {
		fail(c, msg)
		return
	}
	success(c, gin.H{"message": msg})
}

// HandleGetAlarmList 获取所有设置了预警的股票列表
// GET /api/v1/alert/list
func HandleGetAlarmList(c *gin.Context) {
	api := data.NewStockDataApi()
	list, err := api.GetAlarmList()
	if err != nil {
		fail(c, "获取预警列表失败: "+err.Error())
		return
	}
	success(c, list)
}
