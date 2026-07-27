package api

import (
	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// HandleGetIndustryMoneyRank 获取行业资金流向排名
// GET /api/v1/market/industry-money-rank?fenlei=0&sort=netamount
func HandleGetIndustryMoneyRank(c *gin.Context) {
	fenlei := c.DefaultQuery("fenlei", "0")
	sort := c.DefaultQuery("sort", "netamount")

	result := data.NewMarketNewsApi().GetIndustryMoneyRankSina(fenlei, sort)
	if result == nil {
		fail(c, "获取行业资金流向失败")
		return
	}
	success(c, result)
}

// HandleGetIndustryValuation 获取行业估值
// GET /api/v1/market/industry-valuation?name=半导体
func HandleGetIndustryValuation(c *gin.Context) {
	name := c.Query("name")

	result := data.NewStockDataApi().GetIndustryValuation(name)
	if result == nil {
		fail(c, "获取行业估值失败")
		return
	}
	success(c, result)
}

// HandleGetConceptFundFlowRank 获取概念板块资金流向排名
// GET /api/v1/market/concept-fund-flow?topN=20
func HandleGetConceptFundFlowRank(c *gin.Context) {
	topN := 20
	if n := c.Query("topN"); n != "" {
		if v, err := parseInt(n, 20); err == nil {
			topN = v
		}
	}

	result := data.NewConceptFundFlowApi().GetConceptFundFlowTopList(topN)
	success(c, result)
}
