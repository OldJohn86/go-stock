package models

import (
	"time"

	"gorm.io/gorm"
)

// DeviceToken 移动设备推送 Token
type DeviceToken struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Token     string         `gorm:"uniqueIndex;size:512" json:"token"`
	Platform  string         `gorm:"size:20" json:"platform"` // "android" / "ios"
	Active    bool           `json:"active"`
}

func (DeviceToken) TableName() string {
	return "device_tokens"
}
