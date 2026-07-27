package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetStockNotice 获取上市公司公告
// GET /api/v1/market/stock-notice?stockList=000001.SZ,600519.SH
func HandleGetStockNotice(c *gin.Context) {
	stockList := c.Query("stockList")
	if stockList == "" {
		badRequest(c, "参数 stockList 不能为空")
		return
	}

	result := data.NewMarketNewsApi().StockNotice(stockList)
	success(c, result)
}
