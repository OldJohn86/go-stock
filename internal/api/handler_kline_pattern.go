package api

import (
	"math"
	"strconv"

	"go-stock/backend/data"

	"github.com/gin-gonic/gin"
)

// KLinePattern 单个K线形态识别结果
type KLinePattern struct {
	Date      string  `json:"date"`
	Pattern   string  `json:"pattern"`
	Direction string  `json:"direction"` // bullish / bearish
	Score     float64 `json:"score"`     // 置信度 0-1
	Detail    string  `json:"detail"`    // 形态描述
}

// KLinePatternResponse 形态识别结果
type KLinePatternResponse struct {
	StockCode string         `json:"stockCode"`
	Patterns  []KLinePattern `json:"patterns"`
	Summary   string         `json:"summary"`
}

// HandleAnalyzeKLinePattern K线形态识别
// GET /api/v1/kline/pattern/:code?klt=101&limit=120
func HandleAnalyzeKLinePattern(c *gin.Context) {
	code := c.Param("code")
	klt := c.DefaultQuery("klt", "101")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "120"))
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}
	if limit <= 0 || limit > 500 {
		limit = 120
	}

	// 获取K线数据
	api := data.NewEastMoneyKLineApi(data.GetSettingConfig())
	kLinePtr := api.GetKLineDataBefore(code, klt, "", limit, "")
	if kLinePtr == nil || len(*kLinePtr) == 0 {
		fail(c, "未获取到K线数据")
		return
	}
	kLineData := *kLinePtr

	patterns := analyzePatterns(kLineData)
	summary := buildSummary(patterns, code)

	success(c, KLinePatternResponse{
		StockCode: code,
		Patterns:  patterns,
		Summary:   summary,
	})
}

// analyzePatterns 对所有K线进行形态识别
func analyzePatterns(kLines []data.KLineData) []KLinePattern {
	var patterns []KLinePattern

	for i := 0; i < len(kLines); i++ {
		k := kLines[i]

		// 单K线形态
		if p := detectDoji(k); p != nil {
			patterns = append(patterns, *p)
		}
		if p := detectHammer(k); p != nil {
			patterns = append(patterns, *p)
		}
		if p := detectShootingStar(k); p != nil {
			patterns = append(patterns, *p)
		}
		if p := detectLongBody(k); p != nil {
			patterns = append(patterns, *p)
		}
		if p := detectSpinningTop(k); p != nil {
			patterns = append(patterns, *p)
		}

		// 双K线形态
		if i >= 1 {
			if p := detectEngulfing(kLines[i-1], k); p != nil {
				patterns = append(patterns, *p)
			}
			if p := detectHarami(kLines[i-1], k); p != nil {
				patterns = append(patterns, *p)
			}
			if p := detectPiercing(kLines[i-1], k); p != nil {
				patterns = append(patterns, *p)
			}
		}

		// 三K线形态
		if i >= 2 {
			prev2 := kLines[i-2]
			prev1 := kLines[i-1]
			if p := detectThreeSoldiers(prev2, prev1, k); p != nil {
				patterns = append(patterns, *p)
			}
			if p := detectThreeCrows(prev2, prev1, k); p != nil {
				patterns = append(patterns, *p)
			}
			if p := detectMorningStar(prev2, prev1, k); p != nil {
				patterns = append(patterns, *p)
			}
			if p := detectEveningStar(prev2, prev1, k); p != nil {
				patterns = append(patterns, *p)
			}
		}
	}

	return patterns
}

// 辅助类型：用于内部计算的K线数据
type klineCalc struct {
	open  float64
	close float64
	high  float64
	low   float64
	body  float64 // 实体大小
	upper float64 // 上影线
	lower float64 // 下影线
	total float64 // 总振幅
}

func parsePrice(s string) float64 {
	if s == "" {
		return 0
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return 0
	}
	return f
}

func toCalc(k data.KLineData) klineCalc {
	open := parsePrice(k.Open)
	close := parsePrice(k.Close)
	high := parsePrice(k.High)
	low := parsePrice(k.Low)

	body := math.Abs(close - open)
	upper := high - math.Max(open, close)
	lower := math.Min(open, close) - low
	total := high - low
	if total == 0 {
		total = 0.001
	}
	return klineCalc{
		open:  open,
		close: close,
		high:  high,
		low:   low,
		body:  body,
		upper: upper,
		lower: lower,
		total: total,
	}
}

func bodyRatio(c klineCalc) float64 {
	if c.total == 0 {
		return 0
	}
	return c.body / c.total
}

func upperRatio(c klineCalc) float64 {
	if c.total == 0 {
		return 0
	}
	return c.upper / c.total
}

func lowerRatio(c klineCalc) float64 {
	if c.total == 0 {
		return 0
	}
	return c.lower / c.total
}

func isGreen(c klineCalc) bool {
	return c.close > c.open
}
func isRed(c klineCalc) bool {
	return c.close < c.open
}

// ========== 单K线形态检测 ==========

// detectDoji 十字星：实体极小，上下影线比例接近
func detectDoji(k data.KLineData) *KLinePattern {
	c := toCalc(k)
	if c.body/c.total < 0.05 && c.upper/c.total > 0.2 && c.lower/c.total > 0.2 {
		direction := "neutral"
		detail := "十字星形态，多空力量均衡"
		if c.upper > c.lower*1.5 {
			direction = "bearish"
			detail = "墓碑十字星，上影线较长，上方抛压较重"
		} else if c.lower > c.upper*1.5 {
			direction = "bullish"
			detail = "蜻蜓十字星，下影线较长，下方支撑较强"
		}
		return &KLinePattern{
			Date:      k.Day,
			Pattern:   "十字星",
			Direction: direction,
			Score:     0.7,
			Detail:    detail,
		}
	}
	return nil
}

// detectHammer 锤子线：下影线长，实体小，无上影线或极短
func detectHammer(k data.KLineData) *KLinePattern {
	c := toCalc(k)
	if isGreen(c) && c.body/c.total > 0.1 && c.body/c.total < 0.4 &&
		c.lower/c.total > 0.5 && c.upper/c.total < 0.1 {
		return &KLinePattern{
			Date:      k.Day,
			Pattern:   "锤子线",
			Direction: "bullish",
			Score:     0.75,
			Detail:    "下影线较长，实体较小，出现在下跌趋势中可能预示反转",
		}
	}
	return nil
}

// detectShootingStar 射击之星：上影线长，实体小，无下影线或极短
func detectShootingStar(k data.KLineData) *KLinePattern {
	c := toCalc(k)
	if isRed(c) && c.body/c.total > 0.1 && c.body/c.total < 0.4 &&
		c.upper/c.total > 0.5 && c.lower/c.total < 0.1 {
		return &KLinePattern{
			Date:      k.Day,
			Pattern:   "射击之星",
			Direction: "bearish",
			Score:     0.75,
			Detail:    "上影线较长，实体较小，出现在上涨趋势中可能预示反转",
		}
	}
	return nil
}

// detectLongBody 长实体：实体占比超过70%
func detectLongBody(k data.KLineData) *KLinePattern {
	c := toCalc(k)
	if c.body/c.total > 0.7 {
		direction := "bullish"
		pattern := "长阳线"
		if isRed(c) {
			direction = "bearish"
			pattern = "长阴线"
		}
		return &KLinePattern{
			Date:      k.Day,
			Pattern:   pattern,
			Direction: direction,
			Score:     0.6,
			Detail:    "实体较长，显示强烈的" + mapDirection(direction) + "力量",
		}
	}
	return nil
}

// detectSpinningTop 纺锤线：实体适中，上下影线均有
func detectSpinningTop(k data.KLineData) *KLinePattern {
	c := toCalc(k)
	if c.body/c.total > 0.1 && c.body/c.total < 0.4 &&
		c.upper/c.total > 0.2 && c.lower/c.total > 0.2 {
		return &KLinePattern{
			Date:      k.Day,
			Pattern:   "纺锤线",
			Direction: "neutral",
			Score:     0.5,
			Detail:    "实体适中，上下影线均有，多空分歧较大",
		}
	}
	return nil
}

// ========== 双K线形态检测 ==========

// detectEngulfing 吞没形态
func detectEngulfing(prev, curr data.KLineData) *KLinePattern {
	p := toCalc(prev)
	c := toCalc(curr)
	if p.body == 0 || c.body == 0 {
		return nil
	}

	// 看涨吞没：前阴后阳，且阳线实体完全覆盖阴线
	if isRed(p) && isGreen(c) && c.open < p.close && c.close > p.open &&
		c.body > p.body {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "看涨吞没",
			Direction: "bullish",
			Score:     0.8,
			Detail:    "阳线实体完全覆盖前一阴线实体，强烈的反转信号",
		}
	}
	// 看跌吞没：前阳后阴，且阴线实体完全覆盖阳线
	if isGreen(p) && isRed(c) && c.open > p.close && c.close < p.open &&
		c.body > p.body {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "看跌吞没",
			Direction: "bearish",
			Score:     0.8,
			Detail:    "阴线实体完全覆盖前一阳线实体，强烈的反转信号",
		}
	}
	return nil
}

// detectHarami 孕育形态
func detectHarami(prev, curr data.KLineData) *KLinePattern {
	p := toCalc(prev)
	c := toCalc(curr)
	if p.body == 0 || c.body == 0 {
		return nil
	}
	if c.body/p.body > 0.8 {
		return nil
	}

	// 看涨孕育：前阴后阳，阳线实体在阴线实体内
	if isRed(p) && isGreen(c) && c.high < p.high && c.low > p.low {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "看涨孕育",
			Direction: "bullish",
			Score:     0.65,
			Detail:    "小阳线实体孕于大阴线实体中，下跌趋势放缓信号",
		}
	}
	// 看跌孕育：前阳后阴，阴线实体在阳线实体内
	if isGreen(p) && isRed(c) && c.high < p.high && c.low > p.low {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "看跌孕育",
			Direction: "bearish",
			Score:     0.65,
			Detail:    "小阴线实体孕于大阳线实体中，上涨趋势乏力信号",
		}
	}
	return nil
}

// detectPiercing 刺透形态（看涨）和乌云盖顶（看跌）
func detectPiercing(prev, curr data.KLineData) *KLinePattern {
	p := toCalc(prev)
	c := toCalc(curr)
	if p.body == 0 {
		return nil
	}

	// 刺透形态：前阴后阳，阳线收盘价深入阴线实体的1/2以上
	if isRed(p) && isGreen(c) &&
		c.open < p.close && c.close > (p.open+p.close)/2 {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "刺透形态",
			Direction: "bullish",
			Score:     0.7,
			Detail:    "阳线收盘深入到前阴线实体的1/2以上，看涨反转信号",
		}
	}
	// 乌云盖顶：前阳后阴，阴线收盘价深入阳线实体的1/2以上
	if isGreen(p) && isRed(c) &&
		c.open > p.close && c.close < (p.open+p.close)/2 {
		return &KLinePattern{
			Date:      curr.Day,
			Pattern:   "乌云盖顶",
			Direction: "bearish",
			Score:     0.7,
			Detail:    "阴线收盘深入到前阳线实体的1/2以上，看跌反转信号",
		}
	}
	return nil
}

// ========== 三K线形态检测 ==========

// detectThreeSoldiers 三白兵：连续三根上涨阳线
func detectThreeSoldiers(k1, k2, k3 data.KLineData) *KLinePattern {
	c1, c2, c3 := toCalc(k1), toCalc(k2), toCalc(k3)
	if !isGreen(c1) || !isGreen(c2) || !isGreen(c3) {
		return nil
	}
	if c1.body < c2.body*0.5 || c2.body < c3.body*0.5 {
		return nil
	}
	// 每根阳线收盘价越来越高
	if c1.close < c2.close && c2.close < c3.close {
		return &KLinePattern{
			Date:      k3.Day,
			Pattern:   "三白兵",
			Direction: "bullish",
			Score:     0.85,
			Detail:    "连续三根实体渐长的阳线，强势上涨信号",
		}
	}
	return nil
}

// detectThreeCrows 三乌鸦：连续三根下跌阴线
func detectThreeCrows(k1, k2, k3 data.KLineData) *KLinePattern {
	c1, c2, c3 := toCalc(k1), toCalc(k2), toCalc(k3)
	if !isRed(c1) || !isRed(c2) || !isRed(c3) {
		return nil
	}
	if c1.body < c2.body*0.5 || c2.body < c3.body*0.5 {
		return nil
	}
	if c1.close > c2.close && c2.close > c3.close {
		return &KLinePattern{
			Date:      k3.Day,
			Pattern:   "三乌鸦",
			Direction: "bearish",
			Score:     0.85,
			Detail:    "连续三根实体渐长的阴线，强势下跌信号",
		}
	}
	return nil
}

// detectMorningStar 早晨之星
func detectMorningStar(k1, k2, k3 data.KLineData) *KLinePattern {
	c1, c2, c3 := toCalc(k1), toCalc(k2), toCalc(k3)
	// 第一根阴线，第二根小实体（十字星/纺锤线），第三根阳线收复第一根的一半以上
	if !isRed(c1) || !isGreen(c3) {
		return nil
	}
	if c2.body/c1.total > 0.3 || c3.body < c1.body*0.5 {
		return nil
	}
	if c1.close < c2.close && c3.close > (c1.open+c1.close)/2 {
		return &KLinePattern{
			Date:      k3.Day,
			Pattern:   "早晨之星",
			Direction: "bullish",
			Score:     0.8,
			Detail:    "长阴线后出现小实体K线，随后长阳线收复，底部反转信号",
		}
	}
	return nil
}

// detectEveningStar 黄昏之星
func detectEveningStar(k1, k2, k3 data.KLineData) *KLinePattern {
	c1, c2, c3 := toCalc(k1), toCalc(k2), toCalc(k3)
	if !isGreen(c1) || !isRed(c3) {
		return nil
	}
	if c2.body/c1.total > 0.3 || c3.body < c1.body*0.5 {
		return nil
	}
	if c1.close > c2.close && c3.close < (c1.open+c1.close)/2 {
		return &KLinePattern{
			Date:      k3.Day,
			Pattern:   "黄昏之星",
			Direction: "bearish",
			Score:     0.8,
			Detail:    "长阳线后出现小实体K线，随后长阴线下跌，顶部反转信号",
		}
	}
	return nil
}

// ========== 辅助函数 ==========

func mapDirection(d string) string {
	switch d {
	case "bullish":
		return "看涨"
	case "bearish":
		return "看跌"
	default:
		return "中性"
	}
}

// buildSummary 生成形态统计摘要
func buildSummary(patterns []KLinePattern, code string) string {
	if len(patterns) == 0 {
		return "近期的K线走势中未识别出经典形态"
	}

	bullish, bearish, neutral := 0, 0, 0
	for _, p := range patterns {
		switch p.Direction {
		case "bullish":
			bullish++
		case "bearish":
			bearish++
		default:
			neutral++
		}
	}

	// 按置信度排序，找最强的信号
	var bestScore float64
	var bestPattern string
	for _, p := range patterns {
		if p.Score > bestScore {
			bestScore = p.Score
			bestPattern = p.Pattern
		}
	}

	dir := "偏多"
	if bearish > bullish {
		dir = "偏空"
	} else if bearish == bullish {
		dir = "中性"
	}

	return strconv.Itoa(len(patterns)) + "个K线形态被识别，" +
		"其中看涨" + strconv.Itoa(bullish) + "个，" +
		"看跌" + strconv.Itoa(bearish) + "个，" +
		"中性" + strconv.Itoa(neutral) + "个。" +
		"最强信号为「" + bestPattern + "」(置信度" + formatScore(bestScore) + ")，" +
		"整体趋势" + dir + "。" +
		"注意：以上为程序化识别结果，仅供参考，不构成投资建议。"
}

func formatScore(s float64) string {
	return strconv.Itoa(int(s * 100)) + "%"
}

// HandleGetKLinePatternSummary 获取K线形态简单摘要
// GET /api/v1/kline/pattern-summary/:code?klt=101&limit=60
func HandleGetKLinePatternSummary(c *gin.Context) {
	code := c.Param("code")
	klt := c.DefaultQuery("klt", "101")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "60"))
	if code == "" {
		badRequest(c, "股票代码不能为空")
		return
	}

	api := data.NewEastMoneyKLineApi(data.GetSettingConfig())
	kLinePtr := api.GetKLineDataBefore(code, klt, "", limit, "")
	if kLinePtr == nil || len(*kLinePtr) == 0 {
		fail(c, "未获取到K线数据")
		return
	}
	kLineData := *kLinePtr

	patterns := analyzePatterns(kLineData)
	summary := buildSummary(patterns, code)
	latest := kLineData[len(kLineData)-1]

	// 计算简单的趋势统计
	ma5 := calcMA(kLineData, 5)
	ma10 := calcMA(kLineData, 10)
	ma20 := calcMA(kLineData, 20)

	success(c, gin.H{
		"stockCode":  code,
		"latestDate": latest.Day,
		"latestOpen": latest.Open,
		"latestClose": latest.Close,
		"latestHigh": latest.High,
		"latestLow":  latest.Low,
		"ma5":        ma5,
		"ma10":       ma10,
		"ma20":       ma20,
		"trend":      calcTrend(kLineData),
		"patterns":   patterns,
		"summary":    summary,
	})
}

func calcMA(kLines []data.KLineData, days int) float64 {
	if len(kLines) < days {
		days = len(kLines)
	}
	var sum float64
	for i := len(kLines) - days; i < len(kLines); i++ {
		sum += parsePrice(kLines[i].Close)
	}
	return sum / float64(days)
}

func calcTrend(kLines []data.KLineData) string {
	if len(kLines) < 20 {
		return "数据不足"
	}
	// 比较短中期均线
	ma5 := calcMA(kLines, 5)
	ma10 := calcMA(kLines, 10)
	ma20 := calcMA(kLines, 20)
	latest := parsePrice(kLines[len(kLines)-1].Close)

	if latest > ma5 && ma5 > ma10 && ma10 > ma20 {
		return "多头排列"
	}
	if latest < ma5 && ma5 < ma10 && ma10 < ma20 {
		return "空头排列"
	}
	if ma5 > ma20 {
		return "偏多震荡"
	}
	if ma5 < ma20 {
		return "偏空震荡"
	}
	return "横盘震荡"
}
