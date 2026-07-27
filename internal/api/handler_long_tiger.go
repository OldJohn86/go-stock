package api

import (
	"time"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetLongTiger 获取龙虎榜数据
// GET /api/v1/market/long-tiger?date=2026-07-25
func HandleGetLongTiger(c *gin.Context) {
	date := c.DefaultQuery("date", time.Now().Format("2006-01-02"))

	result := data.NewMarketNewsApi().LongTiger(date)
	success(c, result)
}
