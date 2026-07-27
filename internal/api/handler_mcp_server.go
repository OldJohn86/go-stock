package api

import (
	"strconv"

	"go-stock/backend/data"
	"go-stock/backend/models"

	"github.com/gin-gonic/gin"
)

// HandleGetMCPServerList 获取MCP服务器列表
// GET /api/v1/mcp-servers/list?page=1&pageSize=20&name=&status=
func HandleGetMCPServerList(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	name := c.Query("name")
	status := c.Query("status")

	query := &models.MCPServerQuery{
		Page:     page,
		PageSize: pageSize,
		Name:     name,
		Status:   status,
	}

	result := data.NewMCPServerApi().List(query)
	if result == nil {
		success(c, gin.H{"total": 0, "data": []models.MCPServer{}})
		return
	}
	success(c, result)
}

// HandleCreateMCPServer 创建MCP服务器
// POST /api/v1/mcp-servers/create
func HandleCreateMCPServer(c *gin.Context) {
	var server models.MCPServer
	if err := c.ShouldBindJSON(&server); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err := data.NewMCPServerApi().Create(&server)
	if err != nil {
		fail(c, "创建失败: "+err.Error())
		return
	}
	success(c, server)
}

// HandleUpdateMCPServer 更新MCP服务器
// POST /api/v1/mcp-servers/update
func HandleUpdateMCPServer(c *gin.Context) {
	var server models.MCPServer
	if err := c.ShouldBindJSON(&server); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err := data.NewMCPServerApi().Update(&server)
	if err != nil {
		fail(c, "更新失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "更新成功"})
}

// HandleDeleteMCPServer 删除MCP服务器
// POST /api/v1/mcp-servers/delete/:id
func HandleDeleteMCPServer(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的服务器ID")
		return
	}
	err = data.NewMCPServerApi().Delete(uint(id))
	if err != nil {
		fail(c, "删除失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "删除成功"})
}

// HandleEnableMCPServer 启用/禁用MCP服务器
// POST /api/v1/mcp-servers/enable/:id
func HandleEnableMCPServer(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的服务器ID")
		return
	}
	var req struct {
		Enable bool `json:"enable"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "参数错误: "+err.Error())
		return
	}
	err = data.NewMCPServerApi().EnableServer(uint(id), req.Enable)
	if err != nil {
		fail(c, "操作失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": "操作成功"})
}

// HandleTestMCPServer 测试MCP服务器连接
// POST /api/v1/mcp-servers/test/:id
func HandleTestMCPServer(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的服务器ID")
		return
	}
	result, err := data.NewMCPServerApi().TestConnection(uint(id))
	if err != nil {
		fail(c, "测试失败: "+err.Error())
		return
	}
	success(c, gin.H{"message": result})
}

// HandleGetMCPServerTools 获取MCP服务器的工具列表
// GET /api/v1/mcp-servers/tools/:id
func HandleGetMCPServerTools(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 64)
	if err != nil {
		badRequest(c, "无效的服务器ID")
		return
	}
	tools := data.NewMCPServerApi().GetToolsByServerID(uint(id))
	success(c, tools)
}
