package api

import (
	"go-stock/backend/db"
	"go-stock/backend/logger"
	"go-stock/backend/models"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// GET /api/v1/market/sector-stocks
// 根据行业/概念名称获取该板块下的所有股票（带实时行情数据）
// Query params: name=行业名&type=industry|concept&sort=changeRate&page=1&pageSize=50
func HandleGetSectorStocks(c *gin.Context) {
	name := strings.TrimSpace(c.Query("name"))
	sectorType := strings.TrimSpace(c.Query("type"))
	sort := strings.TrimSpace(c.Query("sort"))
	if sort == "" {
		sort = "change_rate"
	}
	page := c.DefaultQuery("page", "1")
	pageSize := c.DefaultQuery("pageSize", "50")

	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name 不能为空"})
		return
	}

	// 根据行业或概念查询数据库中已缓存的股票信息
	query := db.Dao.Model(&models.AllStockInfo{})
	if sectorType == "concept" {
		query = query.Where("CONCEPT LIKE ?", "%"+name+"%")
	} else {
		query = query.Where("INDUSTRY = ?", name)
	}

	var total int64
	query.Count(&total)

	var stocks []models.AllStockInfo
	order := "changerate DESC"
	if sort == "turnoverRate" {
		order = "turnoverrate DESC"
	} else if sort == "price" {
		order = "newprice DESC"
	} else if sort == "volume" {
		order = "volume DESC"
	} else if sort == "amount" {
		order = "dealamount DESC"
	} else if sort == "volumeRatio" {
		order = "volumeratio DESC"
	}

	result := query.Order(order).Offset((_atoi(page)-1)*_atoi(pageSize)).Limit(_atoi(pageSize)).Find(&stocks)
	if result.Error != nil {
		logger.SugaredLogger.Errorf("查询板块股票失败: %v", result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "success",
		"data": gin.H{
			"total": total,
			"page":  _atoi(page),
			"pageSize": _atoi(pageSize),
			"name":  name,
			"type":  sectorType,
			"stocks": stocks,
		},
	})
}

func _atoi(s string) int {
	n := 0
	for _, c := range s {
		if c >= '0' && c <= '9' {
			n = n*10 + int(c-'0')
		} else {
			break
		}
	}
	if n <= 0 {
		n = 1
	}
	return n
}
