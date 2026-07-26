<template>
  <n-space vertical size="large" style="padding: 12px; height: calc(100vh - 80px); overflow-y: auto;">
    <!-- 顶部摘要卡片 -->
    <n-grid :cols="4" :x-gap="12">
      <n-gi>
        <n-card :title="'总资产'" size="small" hoverable>
          <n-statistic :value="totalCapital" :precision="2">
            <template #prefix>¥</template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :title="'持仓市值'" size="small" hoverable>
          <n-statistic :value="totalMarketValue" :precision="2">
            <template #prefix>¥</template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :title="'现金比例'" size="small" hoverable>
          <n-statistic :value="cashPct" :precision="1">
            <template #suffix>%</template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi>
        <n-card :title="'风控评分'" size="small" hoverable>
          <n-statistic :value="riskScore" :precision="0">
            <template #suffix>/100</template>
          </n-statistic>
          <template #footer>
            <n-tag :type="riskLevelTag" size="small">{{ riskLevelText }}</n-tag>
          </template>
        </n-card>
      </n-gi>
    </n-grid>

    <!-- 操作按钮 -->
    <n-space>
      <n-button type="primary" @click="showAddPosition = true" size="small">
        <template #icon><n-icon :component="AddOutline" /></template>
        新建持仓
      </n-button>
      <n-button type="info" @click="showAddTrade = true" size="small">
        <template #icon><n-icon :component="SwapHorizontalOutline" /></template>
        记录交易
      </n-button>
      <n-button type="warning" @click="runRiskAnalysis" size="small" :loading="aiLoading">
        <template #icon><n-icon :component="SparklesOutline" /></template>
        AI 风控分析
      </n-button>
      <n-button @click="refreshAll" size="small">
        <template #icon><n-icon :component="RefreshOutline" /></template>
        刷新
      </n-button>
    </n-space>

    <!-- 持仓列表 -->
    <n-card title="持仓列表" size="small">
      <n-data-table
        :columns="positionColumns"
        :data="positions"
        :loading="posLoading"
        :pagination="false"
        :bordered="false"
        :single-line="false"
        size="small"
        flex-height
        :style="{ maxHeight: '400px' }"
      />
    </n-card>

    <!-- AI 风控面板 -->
    <n-card title="AI 风控建议" size="small" v-if="lastAnalysis.id">
      <n-tag :type="aiRiskLevelTag" size="small" style="margin-bottom: 8px;">
        风控评分: {{ lastAnalysis.risk_score }}/100 · {{ aiRiskLevelText }}
      </n-tag>
      <div style="white-space: pre-wrap; font-size: 13px; line-height: 1.6;">
        {{ aiContent }}
      </div>
      <n-collapse v-if="lastAnalysis.risk_points && lastAnalysis.risk_points.length > 0" style="margin-top: 12px;">
        <n-collapse-item title="风险点详情" name="riskPoints">
          <n-list>
            <n-list-item v-for="(point, idx) in lastAnalysis.risk_points" :key="idx">
              <n-thing :title="point.dimension" :description="point.detail">
                <template #avatar>
                  <n-tag :type="point.severity === 'high' ? 'error' : point.severity === 'medium' ? 'warning' : 'info'" size="tiny">
                    {{ point.severity }}
                  </n-tag>
                </template>
              </n-thing>
            </n-list-item>
          </n-list>
        </n-collapse-item>
      </n-collapse>
    </n-card>

    <!-- 空状态 -->
    <n-empty v-if="positions.length === 0 && !posLoading" description="暂无持仓数据，请先添加持仓">
      <template #icon><n-icon :component="WalletOutline" size="48" /></template>
    </n-empty>

    <!-- 新建持仓对话框 -->
    <n-modal v-model:show="showAddPosition" title="新建持仓" preset="dialog" :style="{ width: '500px' }">
      <n-form ref="addPosFormRef" :model="newPosition" :rules="posRules" label-placement="left" label-width="100px">
        <n-form-item label="股票代码" path="stockCode">
          <n-input v-model:value="newPosition.stockCode" placeholder="例如: 600519" @change="lookupStock" />
        </n-form-item>
        <n-form-item label="股票名称" path="stockName">
          <n-input v-model:value="newPosition.stockName" placeholder="自动填充或手动输入" />
        </n-form-item>
        <n-form-item label="成本价" path="costPrice">
          <n-input-number v-model:value="newPosition.costPrice" :precision="2" :step="0.01" placeholder="买入均价" style="width: 100%" />
        </n-form-item>
        <n-form-item label="持仓数量" path="quantity">
          <n-input-number v-model:value="newPosition.quantity" :precision="0" :step="100" placeholder="股数" style="width: 100%" />
        </n-form-item>
        <n-form-item label="止损比例">
          <n-input-number v-model:value="newPosition.stopLossPct" :precision="1" :step="0.5" placeholder="-8" style="width: 100%">
            <template #suffix>%</template>
          </n-input-number>
        </n-form-item>
      </n-form>
      <template #action>
        <n-button @click="showAddPosition = false">取消</n-button>
        <n-button type="primary" @click="submitAddPosition" :loading="submitting">确认</n-button>
      </template>
    </n-modal>

    <!-- 记录交易对话框 -->
    <n-modal v-model:show="showAddTrade" title="记录交易" preset="dialog" :style="{ width: '500px' }">
      <n-form ref="addTradeFormRef" :model="newTrade" :rules="tradeRules" label-placement="left" label-width="100px">
        <n-form-item label="股票代码" path="stockCode">
          <n-input v-model:value="newTrade.stockCode" placeholder="例如: 600519" />
        </n-form-item>
        <n-form-item label="股票名称" path="stockName">
          <n-input v-model:value="newTrade.stockName" placeholder="股票名称" />
        </n-form-item>
        <n-form-item label="交易类型" path="type">
          <n-radio-group v-model:value="newTrade.type">
            <n-radio value="buy">买入</n-radio>
            <n-radio value="sell">卖出</n-radio>
          </n-radio-group>
        </n-form-item>
        <n-form-item label="成交价" path="price">
          <n-input-number v-model:value="newTrade.price" :precision="2" :step="0.01" placeholder="成交均价" style="width: 100%" />
        </n-form-item>
        <n-form-item label="成交数量" path="quantity">
          <n-input-number v-model:value="newTrade.quantity" :precision="0" :step="100" placeholder="股数" style="width: 100%" />
        </n-form-item>
        <n-form-item label="交易日期" path="tradeDate">
          <n-date-picker v-model:value="tradeDateTs" type="date" placeholder="选择日期" style="width: 100%" />
        </n-form-item>
      </n-form>
      <template #action>
        <n-button @click="showAddTrade = false">取消</n-button>
        <n-button type="primary" @click="submitAddTrade" :loading="tradeSubmitting">确认</n-button>
      </template>
    </n-modal>

    <!-- 纪律警告弹窗 -->
    <n-modal v-model:show="showDisciplineWarn" title="纪律警告" preset="dialog" type="warning" :style="{ width: '450px' }">
      <n-space vertical>
        <n-alert v-for="(warn, idx) in disciplineWarnings" :key="idx" :title="warn.title" :type="warn.type" closable>
          {{ warn.message }}
        </n-alert>
      </n-space>
      <template #action>
        <n-button @click="showDisciplineWarn = false">我知道了</n-button>
        <n-button type="warning" @click="forceAddTrade">仍然执行</n-button>
      </template>
    </n-modal>
  </n-space>
</template>

<script setup>
import { ref, computed, onMounted, h } from 'vue'
import { useMessage, useDialog } from 'naive-ui'
import {
  AddOutline,
  SwapHorizontalOutline,
  SparklesOutline,
  RefreshOutline,
  WalletOutline,
  TrashOutline,
  CreateOutline,
} from '@vicons/ionicons5'
import {
  GetRiskPortfolio,
  AddPosition,
  UpdatePosition,
  DeletePosition,
  GetRiskReport,
  CheckDiscipline,
  AddTrade,
  GetRecentTrades,
  RunRiskAnalysis,
  GetLastRiskAnalysis,
} from '../../wailsjs/go/main/App'

const message = useMessage()
const dialog = useDialog()

// ─── State ─────────────────────────────────────────────
const positions = ref([])
const posLoading = ref(false)
const aiLoading = ref(false)
const submitting = ref(false)
const tradeSubmitting = ref(false)
const totalCapital = ref(100000)
const totalMarketValue = ref(0)
const cashPct = ref(100)
const riskScore = ref(0)
const lastAnalysis = ref({})
const showAddPosition = ref(false)
const showAddTrade = ref(false)
const showDisciplineWarn = ref(false)
const disciplineWarnings = ref([])
const pendingTrade = ref(null)
const tradeDateTs = ref(Date.now())

const newPosition = ref({
  stockCode: '',
  stockName: '',
  costPrice: 0,
  quantity: 0,
  stopLossPct: -8,
})

const newTrade = ref({
  stockCode: '',
  stockName: '',
  type: 'buy',
  price: 0,
  quantity: 0,
  tradeDate: '',
})

const posRules = {
  stockCode: [{ required: true, message: '请输入股票代码', trigger: 'blur' }],
  stockName: [{ required: true, message: '请输入股票名称', trigger: 'blur' }],
  costPrice: [{ required: true, type: 'number', min: 0.01, message: '请输入有效的成本价', trigger: 'blur' }],
  quantity: [{ required: true, type: 'number', min: 1, message: '请输入有效的数量', trigger: 'blur' }],
}

const tradeRules = {
  stockCode: [{ required: true, message: '请输入股票代码', trigger: 'blur' }],
  stockName: [{ required: true, message: '请输入股票名称', trigger: 'blur' }],
  price: [{ required: true, type: 'number', min: 0.01, message: '请输入有效的价格', trigger: 'blur' }],
  quantity: [{ required: true, type: 'number', min: 1, message: '请输入有效的数量', trigger: 'blur' }],
}

// ─── Computed ─────────────────────────────────────────
const riskLevelTag = computed(() => {
  if (!riskScore.value) return 'default'
  if (riskScore.value >= 70) return 'error'
  if (riskScore.value >= 40) return 'warning'
  return 'success'
})

const riskLevelText = computed(() => {
  if (!riskScore.value) return '--'
  if (riskScore.value >= 70) return '高风险'
  if (riskScore.value >= 40) return '中等风险'
  return '低风险'
})

const aiRiskLevelTag = computed(() => {
  if (!lastAnalysis.value.risk_score) return 'default'
  if (lastAnalysis.value.risk_score >= 70) return 'error'
  if (lastAnalysis.value.risk_score >= 40) return 'warning'
  return 'success'
})

const aiRiskLevelText = computed(() => {
  if (!lastAnalysis.value.risk_score) return '--'
  if (lastAnalysis.value.risk_score >= 70) return '高风险'
  if (lastAnalysis.value.risk_score >= 40) return '中等风险'
  return '低风险'
})

const aiContent = computed(() => {
  if (!lastAnalysis.value.id) return '暂无分析结果，请点击"AI 风控分析"按钮触发分析。'
  if (lastAnalysis.value.summary) return lastAnalysis.value.summary
  // Try to parse content JSON
  try {
    const parsed = JSON.parse(lastAnalysis.value.content)
    return parsed.summary || lastAnalysis.value.content
  } catch {
    return lastAnalysis.value.content || ''
  }
})

// ─── Position Table Columns ─────────────────────────
const positionColumns = [
  { title: '股票', key: 'stockName', width: 100, ellipsis: { tooltip: true } },
  { title: '代码', key: 'stockCode', width: 90 },
  {
    title: '成本', key: 'costPrice', width: 90,
    render: (row) => `¥${row.costPrice?.toFixed(2)}`,
  },
  {
    title: '现价', key: 'currentPrice', width: 90,
    render: (row) => `¥${(row.currentPrice || 0).toFixed(2)}`,
  },
  {
    title: '盈亏', key: 'pnlPct', width: 90,
    render: (row) => {
      const pct = row.pnlPct || 0
      const color = pct >= 0 ? '#18a058' : '#d03050'
      return h('span', { style: { color } }, `${pct >= 0 ? '+' : ''}${pct.toFixed(2)}%`)
    },
  },
  {
    title: '仓位', key: 'positionPct', width: 80,
    render: (row) => {
      const pct = row.positionPct || 0
      const color = pct > 30 ? '#d03050' : undefined
      return h('span', { style: { color } }, `${pct.toFixed(1)}%`)
    },
  },
  {
    title: '止损', key: 'stopTriggered', width: 80,
    render: (row) => row.stopTriggered
      ? h('n-tag', { type: 'error', size: 'tiny' }, { default: () => '已触发' })
      : h('n-tag', { type: 'default', size: 'tiny' }, { default: () => '正常' }),
  },
  {
    title: '操作', key: 'actions', width: 120, fixed: 'right',
    render: (row) => {
      return h('n-space', { size: 'small' }, () => [
        h('n-button', {
          size: 'tiny', quaternary: true, type: 'info',
          onClick: () => editPosition(row),
        }, { default: () => h('n-icon', { component: CreateOutline, size: 16 }) }),
        h('n-button', {
          size: 'tiny', quaternary: true, type: 'error',
          onClick: () => deletePosition(row),
        }, { default: () => h('n-icon', { component: TrashOutline, size: 16 }) }),
      ])
    },
  },
]

// ─── Methods ──────────────────────────────────────────
async function refreshAll() {
  await Promise.all([loadPositions(), loadRiskReport()])
}

async function loadPositions() {
  posLoading.value = true
  try {
    positions.value = await GetRiskPortfolio()
  } catch (err) {
    message.error('加载持仓失败: ' + err)
  } finally {
    posLoading.value = false
  }
}

async function loadRiskReport() {
  try {
    const report = await GetRiskReport()
    riskScore.value = report.score || 0
    totalCapital.value = report.totalCapital || 100000
    totalMarketValue.value = report.totalMarketValue || 0
    cashPct.value = report.cashPct || 100
  } catch (err) {
    console.error('load risk report error:', err)
  }
}

async function loadLastAnalysis() {
  try {
    const analysis = await GetLastRiskAnalysis()
    if (analysis && analysis.id) {
      lastAnalysis.value = analysis
    }
  } catch (err) {
    console.error('load last analysis error:', err)
  }
}

function lookupStock() {
  // Stock name lookup is handled server-side
}

function editPosition(row) {
  newPosition.value = {
    stockCode: row.stockCode,
    stockName: row.stockName,
    costPrice: row.costPrice,
    quantity: row.quantity,
    stopLossPct: row.stopLossPct || -8,
  }
  showAddPosition.value = true
}

function deletePosition(row) {
  dialog.warning({
    title: '确认删除',
    content: `确定要删除 ${row.stockName}(${row.stockCode}) 的持仓记录吗？`,
    positiveText: '确定',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await DeletePosition(row.id)
        message.success('删除成功')
        await refreshAll()
      } catch (err) {
        message.error('删除失败: ' + err)
      }
    },
  })
}

async function submitAddPosition() {
  submitting.value = true
  try {
    const pos = newPosition.value
    await AddPosition(pos.stockCode, pos.stockName, pos.costPrice, pos.quantity, pos.stopLossPct)
    message.success('添加成功')
    showAddPosition.value = false
    resetNewPosition()
    await refreshAll()
  } catch (err) {
    message.error('添加失败: ' + err)
  } finally {
    submitting.value = false
  }
}

function resetNewPosition() {
  newPosition.value = {
    stockCode: '',
    stockName: '',
    costPrice: 0,
    quantity: 0,
    stopLossPct: -8,
  }
}

async function submitAddTrade() {
  tradeSubmitting.value = true
  try {
    const trade = {
      stockCode: newTrade.value.stockCode,
      stockName: newTrade.value.stockName,
      type: newTrade.value.type,
      price: newTrade.value.price,
      quantity: newTrade.value.quantity,
      tradeDate: new Date(tradeDateTs.value).toISOString().slice(0, 10),
    }

    // Check discipline rules for buy trades
    if (trade.type === 'buy') {
      const discipline = await CheckDiscipline({
        stockCode: trade.stockCode,
        price: trade.price,
        quantity: trade.quantity,
      })

      if (discipline.blocked) {
        disciplineWarnings.value = discipline.warnings.map(w => ({
          title: w.rule,
          message: w.message,
          type: w.severity === 'block' ? 'error' : 'warning',
        }))
        pendingTrade.value = trade
        showDisciplineWarn.value = true
        tradeSubmitting.value = false
        return
      }

      if (discipline.warnings && discipline.warnings.length > 0) {
        disciplineWarnings.value = discipline.warnings.map(w => ({
          title: w.rule,
          message: w.message,
          type: w.severity === 'block' ? 'error' : 'warning',
        }))
        pendingTrade.value = trade
        showDisciplineWarn.value = true
        tradeSubmitting.value = false
        return
      }
    }

    await AddTrade(trade)
    message.success('交易记录成功')
    showAddTrade.value = false
    resetNewTrade()
    await refreshAll()
  } catch (err) {
    message.error('记录失败: ' + err)
  } finally {
    tradeSubmitting.value = false
  }
}

async function forceAddTrade() {
  showDisciplineWarn.value = false
  tradeSubmitting.value = true
  try {
    await AddTrade(pendingTrade.value)
    message.success('交易记录成功')
    showAddTrade.value = false
    resetNewTrade()
    await refreshAll()
  } catch (err) {
    message.error('记录失败: ' + err)
  } finally {
    tradeSubmitting.value = false
    pendingTrade.value = null
  }
}

function resetNewTrade() {
  newTrade.value = {
    stockCode: '',
    stockName: '',
    type: 'buy',
    price: 0,
    quantity: 0,
    tradeDate: '',
  }
  tradeDateTs.value = Date.now()
}

async function runRiskAnalysis() {
  aiLoading.value = true
  try {
    const result = await RunRiskAnalysis()
    if (result && result.id) {
      lastAnalysis.value = result
      message.success('风控分析完成')
      await loadRiskReport()
    }
  } catch (err) {
    message.error('AI 分析失败: ' + err)
  } finally {
    aiLoading.value = false
  }
}

// ─── Lifecycle ────────────────────────────────────────
onMounted(async () => {
  await Promise.all([loadPositions(), loadRiskReport(), loadLastAnalysis()])
})
</script>
