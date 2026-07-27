package api

import (
	"strconv"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetHotStocks 获取热门股票排行
// GET /api/v1/market/hot-stocks?size=20&marketType=10
func HandleGetHotStocks(c *gin.Context) {
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	marketType := c.DefaultQuery("marketType", "10")

	result := data.NewMarketNewsApi().XUEQIUHotStock(size, marketType)
	success(c, result)
}

// HandleGetHotEvents 获取热门事件
// GET /api/v1/market/hot-events?size=20
func HandleGetHotEvents(c *gin.Context) {
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	result := data.NewMarketNewsApi().HotEvent(size)
	success(c, result)
}

// HandleGetHotTopics 获取热门题材
// GET /api/v1/market/hot-topics?size=20
func HandleGetHotTopics(c *gin.Context) {
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	result := data.NewMarketNewsApi().HotTopic(size)
	success(c, result)
}
