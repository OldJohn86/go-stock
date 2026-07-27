package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleSaveAiConfigs 保存AI配置列表（全量替换）
// POST /api/v1/settings/ai-configs/save
func HandleSaveAiConfigs(c *gin.Context) {
	var configs []*data.AIConfig
	if err := c.ShouldBindJSON(&configs); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}

	msg := data.UpdateAiConfigsOnly(configs)
	if msg != "" {
		fail(c, msg)
		return
	}
	success(c, gin.H{"message": "保存成功"})
}
