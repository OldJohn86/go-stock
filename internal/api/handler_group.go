package api

import (
	"strconv"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetGroupList 获取分组列表（含各分组股票数量）
// GET /api/v1/group/list
func HandleGetGroupList(c *gin.Context) {
	api := data.NewStockGroupApi(nil)
	list := api.GetGroupListWithCount()
	if list == nil {
		success(c, []interface{}{})
		return
	}
	success(c, list)
}

// HandleCreateGroup 创建分组
// POST /api/v1/group/create
func HandleCreateGroup(c *gin.Context) {
	var req struct {
		Name string `json:"name" binding:"required"`
		Sort int    `json:"sort"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入分组名称")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.AddGroup(data.Group{Name: req.Name, Sort: req.Sort})
	if ok {
		success(c, gin.H{"message": "添加成功"})
	} else {
		fail(c, "添加失败")
	}
}

// HandleUpdateGroup 更新分组名称
// POST /api/v1/group/update
func HandleUpdateGroup(c *gin.Context) {
	var req struct {
		Id   int    `json:"id" binding:"required"`
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入分组id和名称")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.UpdateGroup(req.Id, req.Name)
	if ok {
		success(c, gin.H{"message": "修改成功"})
	} else {
		fail(c, "修改失败")
	}
}

// HandleDeleteGroup 删除分组
// POST /api/v1/group/delete/:id
func HandleDeleteGroup(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		badRequest(c, "请输入分组id")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.RemoveGroup(id)
	if ok {
		success(c, gin.H{"message": "删除成功"})
	} else {
		fail(c, "删除失败")
	}
}

// HandleUpdateGroupSort 更新分组排序
// POST /api/v1/group/sort
func HandleUpdateGroupSort(c *gin.Context) {
	var req struct {
		Id      int `json:"id" binding:"required"`
		NewSort int `json:"newSort" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入分组id和新排序")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.UpdateGroupSort(req.Id, req.NewSort)
	success(c, gin.H{"success": ok})
}

// HandleGetGroupStocks 获取分组下的股票列表
// GET /api/v1/group/stocks?groupId=1
func HandleGetGroupStocks(c *gin.Context) {
	groupId, _ := strconv.Atoi(c.DefaultQuery("groupId", "0"))

	api := data.NewStockGroupApi(nil)
	list := api.GetGroupStockByGroupId(groupId)
	if list == nil {
		success(c, []interface{}{})
		return
	}
	success(c, list)
}

// HandleAddStockToGroup 添加股票到分组
// POST /api/v1/group/add-stock
func HandleAddStockToGroup(c *gin.Context) {
	var req struct {
		GroupId   int    `json:"groupId" binding:"required"`
		StockCode string `json:"stockCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入分组id和股票代码")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.AddStockGroup(req.GroupId, req.StockCode)
	if ok {
		success(c, gin.H{"message": "添加成功"})
	} else {
		fail(c, "添加失败")
	}
}

// HandleRemoveStockFromGroup 从分组移除股票
// POST /api/v1/group/remove-stock
func HandleRemoveStockFromGroup(c *gin.Context) {
	var req struct {
		GroupId   int    `json:"groupId" binding:"required"`
		StockCode string `json:"stockCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		badRequest(c, "请输入分组id和股票代码")
		return
	}

	api := data.NewStockGroupApi(nil)
	ok := api.RemoveStockGroup(req.StockCode, "", req.GroupId)
	if ok {
		success(c, gin.H{"message": "移除成功"})
	} else {
		fail(c, "移除失败")
	}
}

// HandleGetAllGroupStocks 获取所有分组-股票归属关系
// GET /api/v1/group/all-stocks
func HandleGetAllGroupStocks(c *gin.Context) {
	api := data.NewStockGroupApi(nil)
	list := api.GetAllGroupStocks()
	if list == nil {
		success(c, []interface{}{})
		return
	}
	success(c, list)
}
