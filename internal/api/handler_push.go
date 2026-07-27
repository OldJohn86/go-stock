package api

import (
	"net/http"
	"strings"

	"go-stock/backend/data"
	"go-stock/backend/logger"

	"github.com/gin-gonic/gin"
)

// RegisterPushTokenRequest 注册设备推送 Token 请求
type RegisterPushTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required"` // "android" 或 "ios"
}

// POST /api/v1/push/register-token
func HandleRegisterPushToken(c *gin.Context) {
	var req RegisterPushTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	platform := strings.ToLower(strings.TrimSpace(req.Platform))
	if platform != "android" && platform != "ios" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "platform 必须为 android 或 ios"})
		return
	}

	if err := data.RegisterDeviceToken(strings.TrimSpace(req.Token), platform); err != nil {
		logger.SugaredLogger.Errorf("注册设备 Token 失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "注册失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "注册成功"})
}

// POST /api/v1/push/unregister-token
func HandleUnregisterPushToken(c *gin.Context) {
	token := strings.TrimSpace(c.PostForm("token"))
	if token == "" {
		// 也支持 JSON body
		var req struct {
			Token string `json:"token"`
		}
		if err := c.ShouldBindJSON(&req); err == nil {
			token = strings.TrimSpace(req.Token)
		}
	}

	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token 不能为空"})
		return
	}

	if err := data.UnregisterDeviceToken(token); err != nil {
		logger.SugaredLogger.Errorf("注销设备 Token 失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "注销失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "注销成功"})
}
