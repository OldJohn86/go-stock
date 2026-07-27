package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// 主要大盘指数代码（A股）
var majorIndices = []string{
	"000001.SH", // 上证指数
	"399001.SZ", // 深证成指
	"399006.SZ", // 创业板指
	"000688.SH", // 科创50
	"000300.SH", // 沪深300
}

// HandleGetIndexList 获取主要大盘指数实时行情
// GET /api/v1/index/list
func HandleGetIndexList(c *gin.Context) {
	api := data.NewStockDataApi()
	stocks, err := api.GetStockCodeRealTimeData(majorIndices...)
	if err != nil || stocks == nil {
		success(c, []interface{}{})
		return
	}
	success(c, stocks)
}
