package data

import (
	"go-stock/backend/db"
	"go-stock/backend/logger"

	"go-stock/backend/models"
)

// RegisterDeviceToken 注册设备 Token
func RegisterDeviceToken(token, platform string) error {
	if token == "" {
		return nil
	}

	var existing models.DeviceToken
	result := db.Dao.Where("token = ?", token).First(&existing)
	if result.Error == nil {
		// Token 已存在，更新状态
		return db.Dao.Model(&existing).Updates(map[string]any{
			"platform": platform,
			"active":   true,
		}).Error
	}

	// 新增 Token
	dt := models.DeviceToken{
		Token:    token,
		Platform: platform,
		Active:   true,
	}
	return db.Dao.Create(&dt).Error
}

// UnregisterDeviceToken 注销设备 Token
func UnregisterDeviceToken(token string) error {
	if token == "" {
		return nil
	}
	// 软删除
	return db.Dao.Where("token = ?", token).Delete(&models.DeviceToken{}).Error
}

// GetAllDeviceTokens 获取所有活跃的设备 Token
func GetAllDeviceTokens() ([]models.DeviceToken, error) {
	var tokens []models.DeviceToken
	result := db.Dao.Where("active = ?", true).Find(&tokens)
	if result.Error != nil {
		logger.SugaredLogger.Errorf("查询设备 Token 失败: %v", result.Error)
		return nil, result.Error
	}
	return tokens, nil
}
