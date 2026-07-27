package data

import (
	"fmt"
	"go-stock/backend/logger"
	"strings"
	"sync"
	"time"

	"github.com/duke-git/lancet/v2/convertor"
)

// AlertMonitorService 盘中预警监控服务
// 后台 goroutine 定期检查自选股的预警条件（变动百分比/价格突破），
// 触发时通过已配置的通道（钉钉/飞书/本地通知/FCM）推送告警。
type AlertMonitorService struct {
	mu        sync.Mutex
	running   bool
	stopCh    chan struct{}
	interval  time.Duration
	triggered map[string]time.Time // 同一只股票同一预警类型 5 分钟内不重复推送
}

var (
	alertMonitorInstance *AlertMonitorService
	alertMonitorOnce     sync.Once
)

// GetAlertMonitorService 返回预警监控服务单例
func GetAlertMonitorService() *AlertMonitorService {
	alertMonitorOnce.Do(func() {
		alertMonitorInstance = &AlertMonitorService{
			interval:  60 * time.Second, // 默认 60 秒检查一次
			triggered: make(map[string]time.Time),
		}
	})
	return alertMonitorInstance
}

// IsRunning 返回监控是否正在运行
func (s *AlertMonitorService) IsRunning() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.running
}

// Start 启动监控
func (s *AlertMonitorService) Start() string {
	s.mu.Lock()
	if s.running {
		s.mu.Unlock()
		return "监控已在运行中"
	}
	s.running = true
	s.stopCh = make(chan struct{})
	s.mu.Unlock()

	go s.monitorLoop()
	logger.SugaredLogger.Info("预警监控服务已启动")
	return "监控已启动"
}

// Stop 停止监控
func (s *AlertMonitorService) Stop() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.running {
		return "监控未运行"
	}
	s.running = false
	close(s.stopCh)
	logger.SugaredLogger.Info("预警监控服务已停止")
	return "监控已停止"
}

// SetInterval 设置检查间隔（秒）
func (s *AlertMonitorService) SetInterval(seconds int) {
	if seconds < 10 {
		seconds = 10
	}
	s.mu.Lock()
	s.interval = time.Duration(seconds) * time.Second
	s.mu.Unlock()
}

func (s *AlertMonitorService) monitorLoop() {
	defer func() {
		if r := recover(); r != nil {
			logger.SugaredLogger.Errorf("预警监控 panic: %v", r)
		}
	}()

	// 首次启动时先执行一次检查
	s.checkAlerts()

	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.checkAlerts()
		case <-s.stopCh:
			return
		}
	}
}

// checkAlerts 获取所有设置了预警的股票，获取实时价格并判断是否触发
func (s *AlertMonitorService) checkAlerts() {
	api := NewStockDataApi()
	alarmList, err := api.GetAlarmList()
	if err != nil {
		logger.SugaredLogger.Errorf("获取预警列表失败: %v", err)
		return
	}
	if len(alarmList) == 0 {
		return
	}

	// 收集所有需要查询的股票代码
	var codes []string
	for _, stock := range alarmList {
		code := strings.TrimSpace(stock.StockCode)
		if code != "" {
			codes = append(codes, code)
		}
	}
	if len(codes) == 0 {
		return
	}

	// 获取实时行情
	infos, err := api.GetStockCodeRealTimeData(codes...)
	if err != nil {
		logger.SugaredLogger.Errorf("获取实时行情失败: %v", err)
		return
	}

	// 构建 code -> StockInfo 的映射
	infoMap := make(map[string]StockInfo)
	if infos != nil {
		for _, info := range *infos {
			infoMap[strings.ToLower(info.Code)] = info
		}
	}

	cfg := GetSettingConfig()
	dingEnabled := cfg != nil && cfg.DingPushEnable
	feishuEnabled := cfg != nil && cfg.FeishuPushEnable
	localEnabled := cfg != nil && cfg.LocalPushEnable
	fcmEnabled := cfg != nil && cfg.FcmPushEnable

	for _, stock := range alarmList {
		code := strings.ToLower(strings.TrimSpace(stock.StockCode))
		realTime, ok := infoMap[code]
		if !ok {
			continue
		}

		currentPrice, _ := convertor.ToFloat(realTime.Price)
		changePercent := realTime.ChangePercent
		alarmChan := stock.AlarmChangePercent
		alarmPrice := stock.AlarmPrice

		var triggered bool
		var msg string

		if alarmChan != 0 {
			// 向上突破：当前涨幅 >= 预警涨幅（且之前没达到）
			// 向下突破：当前跌幅 <= 预警跌幅（负值比较）
			if (alarmChan > 0 && changePercent >= alarmChan) ||
				(alarmChan < 0 && changePercent <= alarmChan) {
				direction := "📈"
				if alarmChan < 0 {
					direction = "📉"
				}
				msg = fmt.Sprintf("%s **%s(%s)** 涨幅预警\n当前涨幅: **%.2f%%**\n预警告警: **%.2f%%**\n当前价格: **%.2f**",
					direction, stock.Name, stock.StockCode, changePercent, alarmChan, currentPrice)
				triggered = true
			}
		}

		if alarmPrice > 0 && !triggered {
			prevClose, _ := convertor.ToFloat(realTime.PreClose)
			if prevClose > 0 && ((currentPrice >= alarmPrice && alarmPrice > prevClose) ||
				(currentPrice <= alarmPrice && alarmPrice < prevClose)) {
				direction := "📈"
				if currentPrice <= alarmPrice {
					direction = "📉"
				}
				msg = fmt.Sprintf("%s **%s(%s)** 价格预警\n当前价格: **%.2f**\n预警价格: **%.2f**\n今日变动: **%.2f%%**",
					direction, stock.Name, stock.StockCode, currentPrice, alarmPrice, changePercent)
				triggered = true
			}
		}

		if triggered && msg != "" {
			triggerKey := fmt.Sprintf("%s_%.2f_%.2f", code, alarmChan, alarmPrice)
			s.mu.Lock()
			lastTrigger, exists := s.triggered[triggerKey]
			shouldSend := true
			if exists && time.Since(lastTrigger) < 5*time.Minute {
				shouldSend = false
			}
			if shouldSend {
				s.triggered[triggerKey] = time.Now()
			}
			s.mu.Unlock()

			if shouldSend {
				s.sendNotification(msg, dingEnabled, feishuEnabled, localEnabled, fcmEnabled)
			}
		}
	}
}

// sendNotification 通过已配置的通道发送通知
func (s *AlertMonitorService) sendNotification(msg string, dingEnabled, feishuEnabled, localEnabled, fcmEnabled bool) {
	if dingEnabled {
		go NewDingDingAPI().SendToDingDing("预警通知", msg)
	}
	if feishuEnabled {
		go NewFeishuAPI().SendToFeishu("预警通知", msg)
	}
	if localEnabled {
		go NewAlertWindowsApi("go-stock", "预警通知", msg, "").SendNotification()
	}
	if fcmEnabled {
		go GetFcmApi().PushToAllDevices("预警通知", msg, map[string]string{
			"type": "alert",
		})
	}
	logger.SugaredLogger.Infof("预警通知已推送: %s", msg)
}
