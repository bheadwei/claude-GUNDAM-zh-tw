---
name: e2e-testing
description: Playwright E2E 測試模式，涵蓋 Page Object Model、設定、CI/CD 整合、測試產物管理及不穩定測試處理策略。
origin: ECC
---

# E2E 測試模式

全面的 Playwright 模式，用於建立穩定、快速且可維護的 E2E 測試套件。

## 測試檔案組織

```
tests/
├── e2e/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   ├── logout.spec.ts
│   │   └── register.spec.ts
│   ├── features/
│   │   ├── browse.spec.ts
│   │   ├── search.spec.ts
│   │   └── create.spec.ts
│   └── api/
│       └── endpoints.spec.ts
├── fixtures/
│   ├── auth.ts
│   └── data.ts
└── playwright.config.ts
```

## Page Object Model (POM)

```typescript
import { Page, Locator } from '@playwright/test'

export class ItemsPage {
  readonly page: Page
  readonly searchInput: Locator
  readonly itemCards: Locator
  readonly createButton: Locator

  constructor(page: Page) {
    this.page = page
    this.searchInput = page.locator('[data-testid="search-input"]')
    this.itemCards = page.locator('[data-testid="item-card"]')
    this.createButton = page.locator('[data-testid="create-btn"]')
  }

  async goto() {
    await this.page.goto('/items')
    await this.page.waitForLoadState('networkidle')
  }

  async search(query: string) {
    await this.searchInput.fill(query)
    await this.page.waitForResponse(resp => resp.url().includes('/api/search'))
    await this.page.waitForLoadState('networkidle')
  }

  async getItemCount() {
    return await this.itemCards.count()
  }
}
```

## 測試結構

```typescript
import { test, expect } from '@playwright/test'
import { ItemsPage } from '../../pages/ItemsPage'

test.describe('項目搜尋', () => {
  let itemsPage: ItemsPage

  test.beforeEach(async ({ page }) => {
    itemsPage = new ItemsPage(page)
    await itemsPage.goto()
  })

  test('應能依關鍵字搜尋', async ({ page }) => {
    await itemsPage.search('test')

    const count = await itemsPage.getItemCount()
    expect(count).toBeGreaterThan(0)

    await expect(itemsPage.itemCards.first()).toContainText(/test/i)
    await page.screenshot({ path: 'artifacts/search-results.png' })
  })

  test('應處理無結果的情境', async ({ page }) => {
    await itemsPage.search('xyznonexistent123')

    await expect(page.locator('[data-testid="no-results"]')).toBeVisible()
    expect(await itemsPage.getItemCount()).toBe(0)
  })
})
```

## Playwright 設定

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'playwright-results.xml' }],
    ['json', { outputFile: 'playwright-results.json' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
    { name: 'mobile-chrome', use: { ...devices['Pixel 5'] } },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
})
```

## 不穩定測試處理

### 隔離標記

```typescript
test('不穩定：複雜搜尋', async ({ page }) => {
  test.fixme(true, '不穩定 - Issue #123')
  // 測試程式碼...
})

test('條件跳過', async ({ page }) => {
  test.skip(process.env.CI, '在 CI 中不穩定 - Issue #123')
  // 測試程式碼...
})
```

### 識別不穩定性

```bash
npx playwright test tests/search.spec.ts --repeat-each=10
npx playwright test tests/search.spec.ts --retries=3
```

### 常見原因與修正

**競態條件：**
```typescript
// 錯誤：假設元素已就緒
await page.click('[data-testid="button"]')

// 正確：自動等待的 locator
await page.locator('[data-testid="button"]').click()
```

**網路時序：**
```typescript
// 錯誤：任意等待時間
await page.waitForTimeout(5000)

// 正確：等待特定條件
await page.waitForResponse(resp => resp.url().includes('/api/data'))
```

**動畫時序：**
```typescript
// 錯誤：在動畫進行中點擊
await page.click('[data-testid="menu-item"]')

// 正確：等待穩定後操作
await page.locator('[data-testid="menu-item"]').waitFor({ state: 'visible' })
await page.waitForLoadState('networkidle')
await page.locator('[data-testid="menu-item"]').click()
```

## 測試產物管理

### 截圖

```typescript
await page.screenshot({ path: 'artifacts/after-login.png' })
await page.screenshot({ path: 'artifacts/full-page.png', fullPage: true })
await page.locator('[data-testid="chart"]').screenshot({ path: 'artifacts/chart.png' })
```

### Traces

```typescript
await browser.startTracing(page, {
  path: 'artifacts/trace.json',
  screenshots: true,
  snapshots: true,
})
// ... 測試動作 ...
await browser.stopTracing()
```

### 錄影

```typescript
// 在 playwright.config.ts 中
use: {
  video: 'retain-on-failure',
  videosPath: 'artifacts/videos/'
}
```

## CI/CD 整合

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
        env:
          BASE_URL: ${{ vars.STAGING_URL }}
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

## 測試報告範本

```markdown
# E2E 測試報告

**日期：** YYYY-MM-DD HH:MM
**耗時：** Xm Ys
**狀態：** 通過 / 失敗

## 摘要
- 總計：X | 通過：Y (Z%) | 失敗：A | 不穩定：B | 跳過：C

## 失敗測試

### 測試名稱
**檔案：** `tests/e2e/feature.spec.ts:45`
**錯誤：** Expected element to be visible
**截圖：** artifacts/failed.png
**建議修正：** [說明]

## 產物
- HTML 報告：playwright-report/index.html
- 截圖：artifacts/*.png
- 錄影：artifacts/videos/*.webm
- Traces：artifacts/*.zip
```
