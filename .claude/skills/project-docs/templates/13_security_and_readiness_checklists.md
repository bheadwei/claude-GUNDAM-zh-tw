# 安全與生產準備檢查清單 - [專案名稱]

> **版本:** v5.0 | **更新:** 2026-07-24 | **狀態:** 範本
> **審查人員:** [安全架構師, 開發者] | **依據:** OWASP ASVS 5.0.0、OWASP Top 10:2025、SLSA v1.1

> 每條可標註等級 **L1**（基本/自動化可測）/ **L2**（標準，多數應用）/ **L3**（高保證，關鍵系統）。依專案風險選擇適用等級，未達等級的項目於「G. 審查結論」列為行動項。

---

## A. 核心安全原則

- [ ] **最小權限**: 元件和使用者僅授予必要權限
- [ ] **縱深防禦**: 多層安全控制，無單點失效
- [ ] **預設安全**: 預設配置是安全的
- [ ] **攻擊面最小化**: 關閉不必要的端口、功能、API

---

## B. ASVS 5.0 章節對照檢查表

> 逐章列出常用控制項；完整需求見 ASVS 5.0.0（可用需求編號如 `v5.0.0-3.2.1` 追溯）。

### V1 — Encoding and Sanitization（編碼與清理）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 輸出依上下文（HTML/JS/URL/SQL）正確編碼 | L1 |
| 2 | 使用經驗證的清理函式庫，非自製 regex | L1 |
| 3 | 富文字輸入採白名單式 HTML 清理 | L2 |

### V2 — Validation and Business Logic（驗證與業務邏輯）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 所有輸入於信任邊界處驗證（型別/範圍/長度） | L1 |
| 2 | 業務邏輯流程無法被跳步/重放濫用 | L2 |
| 3 | 檔案上傳驗證副檔名、MIME、內容簽章 | L1 |

### V3 — Web Frontend Security（前端安全，新增章節）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 已設定 CSP（禁用 `unsafe-inline`/`unsafe-eval`） | L2 |
| 2 | 第三方腳本/樣式使用 SRI（Subresource Integrity） | L2 |
| 3 | 敏感頁面設定 `X-Frame-Options`/`frame-ancestors` 防點擊劫持 | L1 |

### V6 — Authentication（認證）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 密碼使用強 hash（Argon2id/bcrypt），加鹽 | L1 |
| 2 | 多因子驗證（MFA）於高風險操作啟用 | L2 |
| 3 | 帳戶鎖定/速率限制防暴力破解 | L1 |

### V8 — Authorization（授權）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 物件級授權（IDOR 防護，A 無法存取 B 的資料） | L1 |
| 2 | 功能級授權（敏感操作有權限檢查，非僅前端隱藏） | L1 |
| 3 | 授權決策集中化，不散落各端點自行判斷 | L2 |

### V9 — Self-Contained Tokens（自包含權杖，新增章節）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | JWT 驗證簽章演算法白名單（拒絕 `alg=none`） | L1 |
| 2 | Token 設定合理過期時間並支援撤銷（blacklist/短 TTL） | L2 |
| 3 | 敏感 claim 不外洩於 token payload | L2 |

### V10 — OAuth & OIDC（新增章節）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 使用 Authorization Code + PKCE flow | L1 |
| 2 | `redirect_uri` 嚴格白名單比對 | L1 |
| 3 | `state`/`nonce` 防 CSRF 與重放 | L2 |

### V11 — Cryptography（加密）
| # | 項目 | 等級 |
| :--- | :--- | :---: |
| 1 | 敏感資料靜態加密（AES-256） | L1 |
| 2 | 傳輸加密 TLS 1.2+，禁用弱密碼套件 | L1 |
| 3 | 金鑰由 KMS/HSM 管理，不寫死於程式碼 | L2 |

---

## C. OWASP Top 10:2025 逐項檢查

| # | 類別 | 檢查重點 | 狀態 |
| :--- | :--- | :--- | :---: |
| A01 | Broken Access Control（含 SSRF） | 授權檢查、出站請求目標白名單 | ☐ |
| A02 | Security Misconfiguration | 預設帳密已改、除錯模式關閉、標頭安全 | ☐ |
| A03 | Software Supply Chain Failures（新） | 依賴/CI/CD 供應鏈完整性（見 D 節） | ☐ |
| A04 | Cryptographic Failures | 無弱演算法、金鑰管理妥當 | ☐ |
| A05 | Injection | 參數化查詢、命令注入防護 | ☐ |
| A06 | Insecure Design | 威脅建模已執行（→ 詳見 20_threat_model_template.md） | ☐ |
| A07 | Authentication Failures | 見 B 節 V6 | ☐ |
| A08 | Software and Data Integrity Failures | CI/CD 簽章驗證、反序列化白名單 | ☐ |
| A09 | Logging and Monitoring Failures | 安全事件可稽核、告警覆蓋（→ 詳見 19_observability_and_slo_spec.md） | ☐ |
| A10 | Mishandling of Exceptional Conditions（新） | 例外/錯誤路徑不洩露敏感資訊、fail-secure | ☐ |

---

## D. 供應鏈安全（Software Supply Chain）

| 支柱 | 要求 | 工具/產出 | 狀態 |
| :--- | :--- | :--- | :---: |
| SBOM | 每次建置產出 SBOM | CycloneDX 格式 | ☐ |
| VEX | 已知漏洞標註可利用性狀態 | CycloneDX VEX | ☐ |
| 依賴掃描 | CI 自動掃描並阻擋 Critical/High | Dependabot/Snyk/Trivy | ☐ |
| Provenance | 建置產物附證明來源與完整性 | in-toto / sigstore attestation | ☐ |
| SLSA 等級 | 目標建置等級已達成 | Build **L[0-3]**（填目標與現況） | ☐ |

---

## E. 資料安全與隱私

### 資料分類與收集
- [ ] 所有資料依敏感性分類（公開/內部/機密/PII）
- [ ] 只收集業務必要資料，PII 收集前已獲使用者同意

### 傳輸與儲存
- [ ] 外部/內部敏感資料傳輸皆加密（TLS 1.2+）
- [ ] 敏感資料加密儲存（AES-256），備份同等保護

### 資料生命週期
- [ ] 日誌避免記錄敏感資訊（已遮罩/脫敏）
- [ ] 定義資料保留期限，過期資料安全銷毀

---

## F. Secrets 管理

| 項目 | 要求 | 狀態 |
| :--- | :--- | :---: |
| 集中管理 | 使用專用 vault（不落地檔案/程式碼） | ☐ |
| 動態短期憑證 | 依角色簽發，TTL 分鐘～24h | ☐ |
| 自動輪換 | 定期輪換 + 洩露後即時輪換 | ☐ |
| 零硬編碼 | CI 掃描阻擋 commit 內含 secret | ☐ |
| 傳輸/靜態加密 | AES-256 at-rest、TLS 1.2+ in-transit | ☐ |

---

## G. 基礎設施安全

- [ ] 防火牆/安全組遵循最小開放；DDoS 防護已啟用
- [ ] 容器以非 root 執行 + 最小化基礎映像
- [ ] 安全事件日誌 + 即時告警（→ 詳見 19_observability_and_slo_spec.md）

## H. 合規性

- [ ] 已識別適用法規（GDPR/CCPA/HIPAA/其他）
- [ ] 合規要求已落實到設計與實現

---

## I. 生產準備就緒

### 可觀測性
- [ ] 監控儀表板、SLI/SLO 已定義（→ 詳見 19_observability_and_slo_spec.md）
- [ ] 結構化日誌接入中央系統，全鏈路追蹤（OpenTelemetry）

### 可靠性
- [ ] `/health` 健康檢查端點、優雅停機（SIGTERM）
- [ ] 外部呼叫有超時和重試；備份與恢復已演練

### 效能與擴展
- [ ] 負載測試、容量規劃已完成；服務可水平擴展

### 可維護性
- [ ] Runbook 已撰寫（→ 詳見 14_deployment_and_operations_guide.md）
- [ ] CI/CD 流水線完整、配置集中管理、重大變更使用 Feature Flag

---

## J. Sign-off（簽核）

| 角色 | 姓名 | 審查範圍 | 結論 | 日期 |
| :--- | :--- | :--- | :--- | :--- |
| 安全架構師 | [姓名] | ASVS/供應鏈/Secrets | [Pass/Conditional/Fail] | YYYY-MM-DD |
| Tech Lead | [姓名] | 應用/基礎設施 | [Pass/Conditional/Fail] | YYYY-MM-DD |
| 產品負責人 | [姓名] | 合規/上線風險接受 | [Pass/Conditional/Fail] | YYYY-MM-DD |

## K. 審查結論與行動項

| # | 行動項 | 負責人 | 預計完成 | 狀態 |
| :--- | :--- | :--- | :--- | :--- |
| 1 | [修復項] | [人員] | YYYY-MM-DD | 待辦 |

**整體評估:** [可上線 / 完成行動項後可上線 / 不建議上線]
