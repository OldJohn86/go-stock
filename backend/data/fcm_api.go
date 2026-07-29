package data

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go-stock/backend/logger"
	"net/http"
	"strings"
	"sync"
	"time"
)

// FcmApi FCM 推送服务
// 通过 Firebase Cloud Messaging HTTP v1 API 发送推送通知到移动设备
// 需要在设置中配置 Firebase 项目 ID 和 Service Account 密钥
type FcmApi struct {
	projectID  string
	apiKey     string // FCM HTTP v1 需要 OAuth2 token，简化版使用 Server Key / Legacy API Key
	httpClient *http.Client
	enabled    bool
	mu         sync.RWMutex
}

var (
	fcmInstance *FcmApi
	fcmOnce     sync.Once
)

// GetFcmApi 返回 FCM 推送服务单例
func GetFcmApi() *FcmApi {
	fcmOnce.Do(func() {
		fcmInstance = &FcmApi{
			httpClient: &http.Client{Timeout: 10 * time.Second},
		}
		// 从配置加载
		cfg := GetSettingConfig()
		if cfg != nil && cfg.Settings != nil {
			fcmInstance.projectID = cfg.FcmProjectId
			fcmInstance.apiKey = cfg.FcmServerKey
			fcmInstance.enabled = cfg.FcmPushEnable
		}
	})
	return fcmInstance
}

// ReloadConfig 重新加载配置
func (f *FcmApi) ReloadConfig() {
	cfg := GetSettingConfig()
	if cfg != nil && cfg.Settings != nil {
		f.mu.Lock()
		defer f.mu.Unlock()
		f.projectID = cfg.FcmProjectId
		f.apiKey = cfg.FcmServerKey
		f.enabled = cfg.FcmPushEnable
	}
}

// IsEnabled 返回 FCM 推送是否已启用
func (f *FcmApi) IsEnabled() bool {
	f.mu.RLock()
	defer f.mu.RUnlock()
	return f.enabled && f.projectID != "" && f.apiKey != ""
}

// FcmMessage FCM 推送消息结构体
type FcmMessage struct {
	Token        string        `json:"to"` // 兼容 Legacy HTTP API 格式
	Notification *FcmNotify    `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
	Android      *FcmAndroidConfig `json:"android,omitempty"`
	APNS         *FcmAPNSConfig    `json:"apns,omitempty"`
}

type FcmNotify struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type FcmAndroidConfig struct {
	Priority string `json:"priority"`
}

type FcmAPNSConfig struct {
	Headers map[string]string `json:"headers"`
	Payload map[string]any    `json:"payload"`
}

// PushToDevice 向单个设备推送通知
func (f *FcmApi) PushToDevice(token, title, body string, data map[string]string) error {
	f.mu.RLock()
	enabled := f.enabled
	apiKey := f.apiKey
	f.mu.RUnlock()

	if !enabled || apiKey == "" {
		return fmt.Errorf("FCM 推送未启用或未配置")
	}
	if token == "" {
		return fmt.Errorf("设备 Token 为空")
	}

	msg := FcmMessage{
		Token: token,
		Notification: &FcmNotify{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &FcmAndroidConfig{
			Priority: "high",
		},
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("序列化消息失败: %w", err)
	}

	req, err := http.NewRequest("POST", "https://fcm.googleapis.com/fcm/send", bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("创建请求失败: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("key=%s", apiKey))

	resp, err := f.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("发送推送失败: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		var result map[string]any
		json.NewDecoder(resp.Body).Decode(&result)
		return fmt.Errorf("FCM 返回错误(%d): %v", resp.StatusCode, result)
	}

	logger.SugaredLogger.Infof("FCM 推送成功: %s", title)
	return nil
}

// PushToAllDevices 向所有已注册的设备推送通知
// 最多同时推送 maxConcurrentPush 个设备，避免资源耗尽
func (f *FcmApi) PushToAllDevices(title, body string, data map[string]string) {
	if !f.IsEnabled() {
		logger.SugaredLogger.Warn("FCM 推送未启用，跳过推送")
		return
	}

	tokens, err := GetAllDeviceTokens()
	if err != nil || len(tokens) == 0 {
		logger.SugaredLogger.Warn("没有已注册的设备 Token")
		return
	}

	const maxConcurrentPush = 20
	sem := make(chan struct{}, maxConcurrentPush)
	var wg sync.WaitGroup

	for _, t := range tokens {
		if strings.TrimSpace(t.Token) == "" {
			continue
		}
		wg.Add(1)
		sem <- struct{}{} // 阻塞直到有空闲槽位
		go func(token string) {
			defer wg.Done()
			defer func() { <-sem }()
			if err := f.PushToDevice(token, title, body, data); err != nil {
				logger.SugaredLogger.Errorf("FCM 推送失败(token=%s): %v", token[:min(20, len(token))], err)
			}
		}(strings.TrimSpace(t.Token))
	}
	wg.Wait()
}

// PushToDevices 向指定的设备 Token 列表推送通知
func (f *FcmApi) PushToDevices(tokens []string, title, body string, data map[string]string) {
	if !f.IsEnabled() {
		return
	}

	const maxConcurrentPush = 20
	sem := make(chan struct{}, maxConcurrentPush)
	var wg sync.WaitGroup

	for _, token := range tokens {
		if strings.TrimSpace(token) == "" {
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(t string) {
			defer wg.Done()
			defer func() { <-sem }()
			if err := f.PushToDevice(t, title, body, data); err != nil {
				logger.SugaredLogger.Errorf("FCM 推送失败: %v", err)
			}
		}(strings.TrimSpace(token))
	}
	wg.Wait()
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
