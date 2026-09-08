---
name: cost-aware-llm-pipeline
description: 多模型 LLM pipeline 的成本控制模式 — 依複雜度路由、不可變成本追蹤、窄範圍重試、prompt 快取。Use when 要對大量輸入跑 LLM、要把任務分派給不同大小的模型、要加預算上限或成本監控、或 API 費用超出預期要找降本方法。模型 ID、定價與參數限制不在本檔 — 那些載入 `claude-api` skill。
origin: ECC
---

# 成本感知 LLM Pipeline

控制 LLM API 成本同時維持品質的模式。組合模型路由、預算追蹤、重試邏輯和 Prompt 快取為可組合的 pipeline。

## 啟動時機

- 開發呼叫 LLM API 的應用（Claude、GPT 等）
- 處理複雜度不一的批次項目
- 需要控制 API 支出預算
- 在不犧牲複雜任務品質的前提下優化成本

## 核心概念

### 1. 依任務複雜度路由模型

自動為簡單任務選擇便宜模型，複雜任務才用貴的模型。

```python
MODEL_SONNET = "claude-sonnet-5"
MODEL_HAIKU = "claude-haiku-4-5"

_SONNET_TEXT_THRESHOLD = 10_000  # 字元數
_SONNET_ITEM_THRESHOLD = 30     # 項目數

def select_model(
    text_length: int,
    item_count: int,
    force_model: str | None = None,
) -> str:
    """依任務複雜度選擇模型。"""
    if force_model is not None:
        return force_model
    if text_length >= _SONNET_TEXT_THRESHOLD or item_count >= _SONNET_ITEM_THRESHOLD:
        return MODEL_SONNET  # 複雜任務
    return MODEL_HAIKU  # 簡單任務（便宜 3-4 倍）
```

### 2. 不可變成本追蹤

用凍結的 dataclass 追蹤累計支出。每次 API 呼叫回傳新的 tracker，永不修改狀態。

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True)
class CostRecord:
    model: str
    input_tokens: int
    output_tokens: int
    cost_usd: float

@dataclass(frozen=True, slots=True)
class CostTracker:
    budget_limit: float = 1.00
    records: tuple[CostRecord, ...] = ()

    def add(self, record: CostRecord) -> "CostTracker":
        """回傳新增紀錄後的新 tracker（永不修改 self）。"""
        return CostTracker(
            budget_limit=self.budget_limit,
            records=(*self.records, record),
        )

    @property
    def total_cost(self) -> float:
        return sum(r.cost_usd for r in self.records)

    @property
    def over_budget(self) -> bool:
        return self.total_cost > self.budget_limit
```

### 3. 窄範圍重試邏輯

只對暫時性錯誤重試。認證或格式錯誤立即失敗。

```python
from anthropic import (
    APIConnectionError,
    InternalServerError,
    RateLimitError,
)

_RETRYABLE_ERRORS = (APIConnectionError, RateLimitError, InternalServerError)
_MAX_RETRIES = 3

def call_with_retry(func, *, max_retries: int = _MAX_RETRIES):
    """只對暫時性錯誤重試，其餘立即失敗。"""
    for attempt in range(max_retries):
        try:
            return func()
        except _RETRYABLE_ERRORS:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)  # 指數退避
    # AuthenticationError、BadRequestError 等 → 立即拋出
```

### 4. Prompt 快取

快取長系統提示，避免每次請求都重新傳送。

```python
messages = [
    {
        "role": "user",
        "content": [
            {
                "type": "text",
                "text": system_prompt,
                "cache_control": {"type": "ephemeral"},  # 快取此段
            },
            {
                "type": "text",
                "text": user_input,  # 變動部分
            },
        ],
    }
]
```

## 組合使用

在單一 pipeline 函式中結合四種技術：

```python
def process(text: str, config: Config, tracker: CostTracker) -> tuple[Result, CostTracker]:
    # 1. 路由模型
    model = select_model(len(text), estimated_items, config.force_model)

    # 2. 檢查預算
    if tracker.over_budget:
        raise BudgetExceededError(tracker.total_cost, tracker.budget_limit)

    # 3. 帶重試 + 快取呼叫
    response = call_with_retry(lambda: client.messages.create(
        model=model,
        messages=build_cached_messages(system_prompt, text),
    ))

    # 4. 追蹤成本（不可變）
    record = CostRecord(model=model, input_tokens=..., output_tokens=..., cost_usd=...)
    tracker = tracker.add(record)

    return parse_result(response), tracker
```

## 定價與 model ID：不在這裡

**這份 skill 刻意不放定價表與 model ID。** 曾經放過，然後爛掉——表上寫的
`claude-opus-4-8`、`claude-fable-5` 都已不存在，而照著寫的路由程式碼會直接 400。

要 model ID、定價、參數限制（哪些模型移除了 `temperature`/`top_p`/`budget_tokens`）→
**一律載入 `claude-api` skill**，它是這些事實的唯一來源且有人維護。
本檔範例中的 `MODEL_SONNET` / `MODEL_HAIKU` 常數只是佔位，動手前先去核對。

本檔負責的是**不會過期的那一半**：路由決策、成本追蹤、重試、快取的組合方式。

## 最佳實踐

- **從最便宜的模型開始**，只在複雜度閾值達到時才路由到貴的模型
- **處理批次前設定明確預算上限** — 提早失敗優於超支
- **記錄模型選擇決策**，以便根據實際數據調整閾值
- **對超過 1024 tokens 的系統提示使用 Prompt 快取** — 同時省成本和延遲
- **永遠不要對認證或驗證錯誤重試** — 只重試暫時性失敗（網路、限速、伺服器錯誤）

## 應避免的反模式

- 不分複雜度一律用最貴的模型
- 對所有錯誤都重試（在永久性失敗上浪費預算）
- 修改成本追蹤狀態（增加除錯和稽核難度）
- 在程式碼各處硬編碼模型名稱（應使用常數或設定）
- 忽略對重複系統提示的 Prompt 快取
