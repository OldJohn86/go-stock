package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetSettings 获取服务端配置概要（不含密钥）
// GET /api/v1/settings
func HandleGetSettings(c *gin.Context) {
	config := data.GetSettingConfig()
	success(c, gin.H{
		"aiConfigCount": len(config.AiConfigs),
		"openAiEnable":  config.OpenAiEnable,
		"enableAgent":   config.EnableAgent,
		"enableNews":    config.EnableNews,
	})
}

// HandleGetAiConfigs 获取 AI 模型配置列表（脱敏，不含 apiKey）
// GET /api/v1/settings/ai-configs
func HandleGetAiConfigs(c *gin.Context) {
	config := data.GetSettingConfig()

	type AiConfigOut struct {
		ID          uint    `json:"id"`
		Name        string  `json:"name"`
		BaseUrl     string  `json:"baseUrl"`
		ModelName   string  `json:"modelName"`
		MaxTokens   int     `json:"maxTokens"`
		Temperature float64 `json:"temperature"`
		Thinking    bool    `json:"thinking"`
		HasApiKey   bool    `json:"hasApiKey"`
	}

	result := make([]AiConfigOut, 0, len(config.AiConfigs))
	for _, cfg := range config.AiConfigs {
		result = append(result, AiConfigOut{
			ID:          cfg.ID,
			Name:        cfg.Name,
			BaseUrl:     cfg.BaseUrl,
			ModelName:   cfg.ModelName,
			MaxTokens:   cfg.MaxTokens,
			Temperature: cfg.Temperature,
			Thinking:    cfg.Thinking,
			HasApiKey:   cfg.ApiKey != "",
		})
	}
	success(c, result)
}

// HandleFetchAiModels 通过 OpenAI 兼容接口获取模型列表
// GET /api/v1/settings/fetch-models?baseUrl=...&apiKey=...
func HandleFetchAiModels(c *gin.Context) {
	baseUrl := strings.TrimSpace(c.Query("baseUrl"))
	apiKey := strings.TrimSpace(c.Query("apiKey"))

	if baseUrl == "" {
		badRequest(c, "baseUrl 不能为空")
		return
	}

	isOllama := strings.Contains(baseUrl, ":11434") ||
		strings.Contains(strings.ToLower(baseUrl), "ollama")
	if !isOllama && apiKey == "" {
		badRequest(c, "apiKey 不能为空（Ollama 可留空）")
		return
	}

	type modelItem struct {
		ID string `json:"id"`
	}
	type modelResp struct {
		Data []modelItem `json:"data"`
	}

	client := &http.Client{Timeout: 15 * time.Second}
	url := strings.TrimRight(baseUrl, "/") + "/v1/models"

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fail(c, "请求失败: "+err.Error())
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}

	resp, err := client.Do(req)
	if err != nil {
		fail(c, "无法连接到 AI 服务: "+err.Error())
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		msg := fmt.Sprintf("API 返回错误: HTTP %d", resp.StatusCode)
		if len(body) > 0 {
			msg += " " + string(body)
		}
		fail(c, msg)
		return
	}

	var result modelResp
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		fail(c, "解析失败: "+err.Error())
		return
	}

	modelsList := make([]string, 0, len(result.Data))
	for _, m := range result.Data {
		if id := strings.TrimSpace(m.ID); id != "" {
			modelsList = append(modelsList, id)
		}
	}

	success(c, modelsList)
}

// HandleTestAiConnection 测试 AI 服务连接
// GET /api/v1/settings/test-connection?baseUrl=...&apiKey=...
func HandleTestAiConnection(c *gin.Context) {
	baseUrl := strings.TrimSpace(c.Query("baseUrl"))
	apiKey := strings.TrimSpace(c.Query("apiKey"))

	if baseUrl == "" {
		badRequest(c, "baseUrl 不能为空")
		return
	}

	isOllama := strings.Contains(baseUrl, ":11434") ||
		strings.Contains(strings.ToLower(baseUrl), "ollama")
	if !isOllama && apiKey == "" {
		badRequest(c, "apiKey 不能为空（Ollama 可留空）")
		return
	}

	client := &http.Client{Timeout: 10 * time.Second}
	url := strings.TrimRight(baseUrl, "/") + "/v1/models"

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		fail(c, "请求失败: "+err.Error())
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}

	resp, err := client.Do(req)
	if err != nil {
		fail(c, "无法连接: "+err.Error())
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		success(c, gin.H{"status": "ok", "message": "连接成功"})
	} else {
		fail(c, fmt.Sprintf("连接失败: HTTP %d", resp.StatusCode))
	}
}