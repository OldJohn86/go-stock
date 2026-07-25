package api

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

// Response 统一响应格式
type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

func success(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Code:    0,
		Message: "success",
		Data:    data,
	})
}

func fail(c *gin.Context, msg string) {
	c.JSON(http.StatusOK, Response{
		Code:    -1,
		Message: msg,
	})
}

func failf(c *gin.Context, format string, args ...interface{}) {
	fail(c, fmt.Sprintf(format, args...))
}

func badRequest(c *gin.Context, msg string) {
	c.JSON(http.StatusBadRequest, Response{
		Code:    http.StatusBadRequest,
		Message: msg,
	})
}
