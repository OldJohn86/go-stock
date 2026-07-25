package api

import (
	"encoding/json"
	"fmt"
	"io"
	"strconv"

	"go-stock/backend/agent"

	"github.com/gin-gonic/gin"
)

// HandleAgentChatSSE AI 对话流式接口（Server-Sent Events）
// GET /api/v1/agent/chat?question=...&aiConfigId=1&memoryMode=true&thinkingMode=false&agentMode=react&sessionId=
func HandleAgentChatSSE(c *gin.Context) {
	question := c.Query("question")
	if question == "" {
		badRequest(c, "question 不能为空")
		return
	}

	aiConfigID, _ := strconv.Atoi(c.DefaultQuery("aiConfigId", "1"))
	memoryMode, _ := strconv.ParseBool(c.DefaultQuery("memoryMode", "true"))
	thinkingMode, _ := strconv.ParseBool(c.DefaultQuery("thinkingMode", "false"))
	memoryCount, _ := strconv.Atoi(c.DefaultQuery("memoryCount", "10"))
	agentMode := c.DefaultQuery("agentMode", "react")
	sessionID := c.Query("sessionId")

	// 设置 SSE 响应头
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")

	// 创建请求上下文，响应客户端断开时取消
	ctx := c.Request.Context()

	ch := agent.NewStockAiAgentApi().ChatWithContext(
		ctx, question, aiConfigID, nil,
		memoryMode, memoryCount, thinkingMode, agentMode, "", sessionID,
	)

	c.Stream(func(w io.Writer) bool {
		msg, ok := <-ch
		if !ok {
			// 流结束
			sendSSEData(w, "[DONE]", "done")
			return false
		}
		if msg == nil {
			return true
		}

		// 流式内容块
		data := map[string]interface{}{
			"role":    string(msg.Role),
			"content": msg.Content,
		}
		if msg.ReasoningContent != "" {
			data["reasoningContent"] = msg.ReasoningContent
		}

		jsonData, _ := json.Marshal(data)
		sendSSEData(w, string(jsonData), "message")
		return true
	})
}

// HandleAgentChat JSON 非流式对话（适合移动端简单调用）
// POST /api/v1/agent/chat
func HandleAgentChat(c *gin.Context) {
	var req struct {
		Question      string `json:"question" binding:"required"`
		AIConfigID    int    `json:"aiConfigId"`
		MemoryMode    bool   `json:"memoryMode"`
		ThinkingMode  bool   `json:"thinkingMode"`
		MemoryCount   int    `json:"memoryCount"`
		AgentMode     string `json:"agentMode"`
		SessionID     string `json:"sessionId"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	if req.AIConfigID == 0 {
		req.AIConfigID = 1
	}
	if req.AgentMode == "" {
		req.AgentMode = "react"
	}
	if req.MemoryCount == 0 {
		req.MemoryCount = 10
	}

	ctx := c.Request.Context()
	ch := agent.NewStockAiAgentApi().ChatWithContext(
		ctx, req.Question, req.AIConfigID, nil,
		req.MemoryMode, req.MemoryCount, req.ThinkingMode, req.AgentMode, "", req.SessionID,
	)

	var content string
	var reasoningContent string
	for msg := range ch {
		if msg == nil {
			continue
		}
		content += msg.Content
		if msg.ReasoningContent != "" {
			reasoningContent += msg.ReasoningContent
		}
	}

	success(c, gin.H{
		"content":          content,
		"reasoningContent": reasoningContent,
	})
}

func sendSSEData(w io.Writer, data, event string) {
	if event != "" {
		fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, data)
	} else {
		fmt.Fprintf(w, "data: %s\n\n", data)
	}
	if flusher, ok := w.(interface{ Flush() }); ok {
		flusher.Flush()
	}
}

// HandleGetAgentConfigs 获取 AI 配置列表
// GET /api/v1/agent/configs
func HandleGetAgentConfigs(c *gin.Context) {
	// TODO: 从 data.AIConfig 查询
	success(c, nil)
}
