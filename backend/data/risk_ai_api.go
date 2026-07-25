package data

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"go-stock/backend/db"
	"go-stock/backend/models"
	"net/http"
	"strings"
	"time"
)

type RiskAIApi struct {
	settings *Settings
}

func NewRiskAIApi(s *Settings) *RiskAIApi {
	return &RiskAIApi{settings: s}
}

// RunAnalysis 执行 AI 风控分析，返回缓存的分析结果

// getAiMode 获取 AI 模式
func (a *RiskAIApi) getAiMode() string {
	if a.settings.OpenAiEnable {
		return "openai"
	}
	return "ollama"
}

// getAiBaseURL 获取 AI API 基础 URL
func (a *RiskAIApi) getAiBaseURL() string {
	configs := GetSettingConfig().AiConfigs
	if len(configs) > 0 {
		return configs[0].BaseUrl
	}
	return ""
}

// getAiModel 获取 AI 模型名称
func (a *RiskAIApi) getAiModel() string {
	configs := GetSettingConfig().AiConfigs
	if len(configs) > 0 {
		return configs[0].ModelName
	}
	return ""
}

// getAiApiKey 获取 AI API Key
func (a *RiskAIApi) getAiApiKey() string {
	configs := GetSettingConfig().AiConfigs
	if len(configs) > 0 {
		return configs[0].ApiKey
	}
	return ""
}

func (a *RiskAIApi) RunAnalysis(positions []PositionWithPnL, recentTrades []models.Trade, risk RiskReport, trigger string, onToken func(string)) (models.AIAnalysis, error) {
	prompt := a.buildPrompt(positions, recentTrades, risk)

	var raw string
	mode := a.getAiMode()

	switch mode {
	case "ollama":
		raw = a.callOllama(prompt, onToken)
	case "openai":
		raw = a.callOpenAI(prompt, onToken)
	default:
		raw = a.callOllama(prompt, onToken)
	}

	// Parse structured output
	output := a.parseStructuredOutput(raw)

	// Validate risk score
	if output.RiskScore < 0 || output.RiskScore > 100 {
		output.RiskScore = risk.Score
	}
	if output.Summary == "" {
		output.Summary = raw
		if len(output.Summary) > 500 {
			output.Summary = output.Summary[:500]
		}
	}

	// Determine content type
	contentType := "plain"
	if output.RiskScore > 0 || len(output.RiskPoints) > 0 || len(output.Suggestions) > 0 {
		contentType = "structured"
	}

	// Marshal output to JSON for storage
	contentBytes, _ := json.Marshal(output)
	content := string(contentBytes)
	if contentType == "plain" {
		content = raw
	}

	// Save to DB
	analysis := models.AIAnalysis{
		RiskScore:   output.RiskScore,
		Content:     content,
		ContentType: contentType,
		Trigger:     trigger,
	}
	if err := db.Dao.Create(&analysis).Error; err != nil {
		return models.AIAnalysis{}, err
	}

	return analysis, nil
}

// GetLastAnalysis 获取最近一次风控分析结果
func (a *RiskAIApi) GetLastAnalysis() models.AIAnalysis {
	var analysis models.AIAnalysis
	result := db.Dao.Order("created_at desc").First(&analysis)
	if result.Error != nil {
		return models.AIAnalysis{}
	}
	return analysis
}

// buildPrompt 构建风控分析 prompt
func (a *RiskAIApi) buildPrompt(positions []PositionWithPnL, recentTrades []models.Trade, risk RiskReport) string {
	var sb strings.Builder

	sb.WriteString("你是一个A股散户的风控助手。请分析用户的持仓结构和交易行为风险。\n\n")
	sb.WriteString("【重要约束】\n")
	sb.WriteString("- 不得推荐任何股票买卖\n")
	sb.WriteString("- 不得预测股价涨跌\n")
	sb.WriteString("- 只分析仓位结构、风险状况和行为纪律\n\n")

	sb.WriteString(fmt.Sprintf("风控评分: %d/100 (等级: %s)\n", risk.Score, risk.Level))
	sb.WriteString(fmt.Sprintf("现金比例: %.1f%%\n", risk.CashPct))
	sb.WriteString(fmt.Sprintf("持仓个股: %d 只\n", risk.PositionCount))
	sb.WriteString(fmt.Sprintf("近7天交易: %d 次\n", risk.TradeCount))
	sb.WriteString("\n")

	if len(positions) > 0 {
		sb.WriteString("持仓详情:\n")
		for i, pos := range positions {
			sb.WriteString(fmt.Sprintf("%d. %s(%s) 成本%.2f 现价%.2f 盈亏%.1f%% 仓位%.1f%%\n",
				i+1, pos.StockName, pos.StockCode, pos.CostPrice, pos.CurrentPrice, pos.PnLPct, pos.PositionPct))
		}
		sb.WriteString("\n")
	}

	// 风险项摘要
	if len(risk.Items) > 0 {
		sb.WriteString("风险维度:\n")
		for _, item := range risk.Items {
			sb.WriteString(fmt.Sprintf("- [%s] +%d分: %s\n", item.Dimension, item.Score, item.Message))
		}
		sb.WriteString("\n")
	}

	sb.WriteString("请严格按照以下 JSON 格式输出，不要添加任何额外文字：\n")
	sb.WriteString(`{
  "risk_score": <0-100整数>,
  "summary": "<一句中文总结>",
  "risk_points": [
    {"dimension": "<风险维度>", "severity": "high|medium|low", "detail": "<具体说明>"}
  ],
  "suggestions": ["<建议1>", "<建议2>"]
}`)

	return sb.String()
}

// callOllama 调用本地 Ollama API
func (a *RiskAIApi) callOllama(prompt string, onToken func(string)) string {
	baseURL := a.getAiBaseURL()
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}
	model := a.getAiModel()
	if model == "" {
		model = "qwen2.5"
	}

	payload := map[string]interface{}{
		"model":  model,
		"prompt": prompt,
		"stream": true,
	}
	body, _ := json.Marshal(payload)

	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Post(baseURL+"/api/generate", "application/json", bytes.NewReader(body))
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	var full strings.Builder
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		var chunk struct {
			Response string `json:"response"`
			Done     bool   `json:"done"`
		}
		if err := json.Unmarshal([]byte(line), &chunk); err != nil {
			continue
		}
		full.WriteString(chunk.Response)
		if onToken != nil && chunk.Response != "" {
			onToken(chunk.Response)
		}
		if chunk.Done {
			break
		}
	}

	return full.String()
}

// callOpenAI 调用 OpenAI 兼容 API
func (a *RiskAIApi) callOpenAI(prompt string, onToken func(string)) string {
	baseURL := a.getAiBaseURL()
	if baseURL == "" {
		baseURL = "https://api.openai.com/v1"
	}
	model := a.getAiModel()
	if model == "" {
		model = "gpt-4o-mini"
	}
	apiKey := a.getAiApiKey()

	payload := map[string]interface{}{
		"model": model,
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
		"stream":          true,
		"response_format": map[string]string{"type": "json_object"},
	}
	body, _ := json.Marshal(payload)

	req, _ := http.NewRequest("POST", strings.TrimRight(baseURL, "/")+"/chat/completions", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+apiKey)
	}

	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	var full strings.Builder
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			break
		}
		var chunk struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}
		if len(chunk.Choices) > 0 {
			token := chunk.Choices[0].Delta.Content
			full.WriteString(token)
			if onToken != nil && token != "" {
				onToken(token)
			}
		}
	}

	return full.String()
}

// parseStructuredOutput 解析结构化 JSON 输出
func (a *RiskAIApi) parseStructuredOutput(raw string) AIAnalysisOutput {
	var output AIAnalysisOutput

	// Try direct unmarshal
	if err := json.Unmarshal([]byte(raw), &output); err == nil {
		return a.validateOutput(output)
	}

	// Try extract JSON block
	jsonStr := extractJSONBlock(raw)
	if jsonStr != "{}" {
		if err := json.Unmarshal([]byte(jsonStr), &output); err == nil {
			return a.validateOutput(output)
		}
	}

	return output
}

// extractJSONBlock 从文本中提取 JSON 块
func extractJSONBlock(raw string) string {
	// Try markdown code block
	if idx := strings.Index(raw, "```json"); idx >= 0 {
		rest := raw[idx+7:]
		if end := strings.Index(rest, "```"); end >= 0 {
			trimmed := strings.TrimSpace(rest[:end])
			if json.Valid([]byte(trimmed)) {
				return trimmed
			}
		}
	}

	// Try first { to last }
	if start := strings.Index(raw, "{"); start >= 0 {
		if end := strings.LastIndex(raw, "}"); end > start {
			try := raw[start : end+1]
			if json.Valid([]byte(try)) {
				return try
			}
		}
	}

	// Try if the whole thing is valid JSON
	if json.Valid([]byte(raw)) {
		return raw
	}

	return "{}"
}

// validateOutput 校验并修正输出
func (a *RiskAIApi) validateOutput(output AIAnalysisOutput) AIAnalysisOutput {
	if output.RiskScore < 0 {
		output.RiskScore = 0
	}
	if output.RiskScore > 100 {
		output.RiskScore = 100
	}
	// Validate severity values
	for i, rp := range output.RiskPoints {
		switch rp.Severity {
		case "high", "medium", "low":
		default:
			output.RiskPoints[i].Severity = "medium"
		}
	}
	return output
}
