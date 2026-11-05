# update-template.ps1 — 將 claude_v2026 模板的「最新資產」更新到既有專案
#
# 與 copy-template.ps1 的差異：
#   copy-template   = 開新專案（複製到空資料夾）
#   update-template = 更新既有專案（只更新模板資產，保留該專案的 log/plan/qa-history/sessions）
#
# 用法:
#   .\scripts\update-template.ps1 -Destination D:\projects\my-app
#   .\scripts\update-template.ps1 D:\projects\my-app -DryRun      # 只預覽不寫入
#   .\scripts\update-template.ps1 D:\projects\my-app -Prune       # 連目標多出來的模板檔一起清掉
#   .\scripts\update-template.ps1 D:\projects\my-app -NoBackup    # 不先備份（不建議）
#   .\scripts\update-template.ps1 D:\projects\my-app -ClaudeOnly  # 只更新 .claude\，完全不碰根目錄資產

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Destination,

    [switch]$DryRun,      # 只列出將變更的內容，不實際寫入
    [switch]$Prune,       # 對 SYNC 目錄使用 /MIR，刪除目標多出來的檔（預設僅新增/覆蓋）
    [switch]$NoBackup,    # 略過備份（預設會先把目標 .claude 壓成 zip）
    [switch]$ClaudeOnly   # 只更新 .claude\，跳過根層檔案（.gitattributes）
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# 路徑與分類設定
# ============================================================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source     = (Resolve-Path (Join-Path $scriptRoot '..')).Path.TrimEnd('\')

# --- SYNC：純模板資產，覆寫；加 -Prune 時連舊檔一起清 ---
$syncClaudeDirs = @(
    'agents', 'commands', 'rules', 'skills', 'hooks', 'guides',
    'output-styles', 'plugins', 'templates', 'ui', 'scripts'
)
$syncClaudeFiles = @(
    'statusline.sh', 'statusline-debug.sh',
    'settings.json', 'README.md'
)
# 根目錄的 scripts\ 與 .mcp.json.*.example 刻意不同步：專案有自己的 scripts\，
# 模板的維護腳本混進去只會讓使用者每次手動刪；mcp 範例只在開新專案時有用（copy-template 帶）。
# 目標端已經有的也不刪——可能是使用者自己的檔案。update-template.sh 要一致
# CLAUDE_TEMPLATE.md 已廢除（初始化狀態改看 taskmaster-data/project.json），不再同步
$syncRootFiles = @('.gitattributes')
# SEED：只在目標「不存在」時建立，永不覆寫（專案會自己加規則，且根目錄檔案沒備份）
$seedRootFiles = @('.worktreeinclude')

# --- MERGE：補骨架（README/_TEMPLATE/.gitkeep），但保留執行資料，永不刪除 ---
$mergeClaudeDirs = @('context', 'coordination')

# --- PRESERVE：完全不碰（清單僅供顯示，邏輯上是「不在上面就不碰」）---
$preserveNote = @(
    'settings.local.json', 'taskmaster-data/', 'sessions/',
    'logs/', 'qa-history/', 'worktrees/', '(root) .mcp.json / .env'
)

# ============================================================================
# 驗證
# ============================================================================

if (-not (Test-Path $Destination)) {
    Write-Host "❌ 目標資料夾不存在: $Destination" -ForegroundColor Red
    Write-Host "   若要開新專案，請改用 copy-template.ps1" -ForegroundColor Yellow
    exit 1
}
$destPath = (Resolve-Path $Destination).Path.TrimEnd('\')

if ($destPath -eq $source) {
    Write-Host "❌ 目標不能是模板本身" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $destPath '.claude'))) {
    Write-Host "⚠️  目標沒有 .claude 目錄，看起來不是既有專案。" -ForegroundColor Yellow
    Write-Host "   若要從零建立，請改用 copy-template.ps1" -ForegroundColor Yellow
    $answer = Read-Host "仍要繼續（會直接寫入模板資產）？[y/N]"
    if ($answer -notmatch '^[Yy]$') { Write-Host "已取消"; exit 0 }
}

# ============================================================================
# 備份目標 .claude
# ============================================================================

if (-not $DryRun -and -not $NoBackup -and (Test-Path (Join-Path $destPath '.claude'))) {
    $ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $destPath '.claude-backups'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $backupZip = Join-Path $backupDir "claude-backup-$ts.zip"
    Write-Host "🛟 備份目標 .claude → $backupZip" -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $destPath '.claude\*') -DestinationPath $backupZip -Force
}

# ============================================================================
# robocopy 包裝
# ============================================================================

function Invoke-Sync {
    param([string]$Src, [string]$Dst, [switch]$Mirror, [switch]$AdditiveOnly)

    if (-not (Test-Path $Src)) { return }   # 模板沒有就跳過
    New-Item -ItemType Directory -Path $Dst -Force | Out-Null

    $rc = @($Src.TrimEnd('\'), $Dst.TrimEnd('\'), '/E', '/R:1', '/W:1', '/NP', '/NDL', '/NFL', '/NJH', '/NJS')
    if ($Mirror -and -not $AdditiveOnly) { $rc += '/PURGE' }   # /E + /PURGE = /MIR 效果
    if ($DryRun) { $rc += '/L' }

    & robocopy @rc | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Host "❌ robocopy 失敗 ($Src) exit=$LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}

function Copy-OneFile {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) { return }
    if ($DryRun) { Write-Host "   [dry] $Dst"; return }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Dst) -Force | Out-Null
    Copy-Item -Path $Src -Destination $Dst -Force
}

# ============================================================================
# 執行
# ============================================================================

$mode = if ($DryRun) { 'DRY-RUN（不寫入）' } elseif ($Prune) { 'SYNC + PRUNE' } else { 'SYNC（不刪除）' }
if ($ClaudeOnly) { $mode += ' · CLAUDE-ONLY' }
Write-Host ""
Write-Host "🔄 更新模板資產 [$mode]" -ForegroundColor Cyan
Write-Host "   來源: $source"
Write-Host "   目標: $destPath"
if ($ClaudeOnly) { Write-Host "   範圍: 僅 .claude\（跳過根目錄資產）" -ForegroundColor DarkYellow }
Write-Host ""

Write-Host "▶ SYNC 模板目錄..." -ForegroundColor Green
foreach ($d in $syncClaudeDirs) {
    Invoke-Sync (Join-Path $source ".claude\$d") (Join-Path $destPath ".claude\$d") -Mirror:$Prune
}

Write-Host "▶ SYNC 模板檔案..." -ForegroundColor Green
foreach ($f in $syncClaudeFiles) {
    Copy-OneFile (Join-Path $source ".claude\$f") (Join-Path $destPath ".claude\$f")
}
if (-not $ClaudeOnly) {
    foreach ($f in $syncRootFiles) {
        Copy-OneFile (Join-Path $source $f) (Join-Path $destPath $f)
    }
} else {
    Write-Host "   ⏭  跳過根目錄檔案: $($syncRootFiles -join ', ')" -ForegroundColor DarkGray
}

$srcRootU = (Resolve-Path $source).Path.TrimEnd('\')
Write-Host "▶ SEED 根目錄檔案（只補缺少的，永不覆寫）..." -ForegroundColor Green
foreach ($f in $seedRootFiles) {
    $target = Join-Path $destPath $f
    if (Test-Path $target) {
        Write-Host "   ⏭  已存在，跳過: $f" -ForegroundColor DarkGray
    } elseif ($DryRun) {
        Write-Host "   [dry] $target" -ForegroundColor DarkGray
    } else {
        Copy-Item -Path (Join-Path $srcRootU $f) -Destination $target -Force
        Write-Host "   ✚ 已建立: $f" -ForegroundColor Cyan
    }
}

# .gitignore 不能整份覆寫（專案自己加過規則、根目錄檔案沒備份），但模板新增的短命狀態檔
# （.last-verify、.merge-round-open…）不補進去的話會被 commit。所以只做一件事：
# 模板 .gitignore 裡 `.claude/taskmaster-data/` 開頭的行，目標沒有的才接在檔尾。
# 既有的行一行都不動、不排序、不去重；換行符照目標原本的（CRLF 就補 CRLF）。update-template.sh 要一致
Write-Host "▶ 補 .gitignore 的執行時短命狀態（只補缺少的行，不動既有的）..." -ForegroundColor Green
$giSrc = Join-Path $srcRootU '.gitignore'
$giDst = Join-Path $destPath '.gitignore'
if ($ClaudeOnly) {
    Write-Host "   ⏭  -ClaudeOnly：跳過" -ForegroundColor DarkGray
} elseif (Test-Path -LiteralPath $giSrc) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $dstText = ''
    if (Test-Path -LiteralPath $giDst) { $dstText = [System.IO.File]::ReadAllText($giDst, $utf8) }
    # gitignore 區分大小寫，不能用 PowerShell 預設不分大小寫的 hashtable
    $have = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($l in ($dstText -split "`n")) { [void]$have.Add($l.TrimEnd()) }
    $giMissing = New-Object 'System.Collections.Generic.List[string]'
    foreach ($l in [System.IO.File]::ReadAllLines($giSrc, $utf8)) {
        $t = $l.TrimEnd()
        if ($t.StartsWith('.claude/taskmaster-data/', [System.StringComparison]::Ordinal) -and $have.Add($t)) { $giMissing.Add($t) }
    }
    if ($giMissing.Count -eq 0) {
        Write-Host "   ✓ 已齊全" -ForegroundColor DarkGray
    } elseif ($DryRun) {
        Write-Host "   [dry] 會補進 .gitignore：$($giMissing -join ' ')" -ForegroundColor DarkGray
    } else {
        $nl = if ($dstText.Contains("`r`n")) { "`r`n" } else { "`n" }
        $add = ''
        # 檔尾沒有換行就先補一個，免得第一行接到別人的規則後面
        if ($dstText.Length -gt 0 -and -not $dstText.EndsWith("`n")) { $add += $nl }
        $add += $nl + '# 執行時短命狀態（update-template 補上；理由見模板的 .gitignore）' + $nl
        foreach ($l in $giMissing) { $add += $l + $nl }
        [System.IO.File]::AppendAllText($giDst, $add, $utf8)
        Write-Host "   ✚ 已補 $($giMissing.Count) 行：$($giMissing -join ' ')" -ForegroundColor Cyan
    }
}

Write-Host "▶ MERGE 骨架目錄（保留執行資料）..." -ForegroundColor Green
# 只補骨架檔（README.md / _*.md / .gitkeep）與目錄結構。
#
# 為什麼不用 Invoke-Sync -AdditiveOnly：那會整包複製，把**模板 repo 自己**累積的
# agent 報告（context\quality\*.md 等）灌進使用者專案。骨架是模板資產，報告是專案
# 資料。與 update-template.sh 及 copy-template.{sh,ps1} 同一套規則，四份必須一致。
foreach ($d in $mergeClaudeDirs) {
    $srcDir = Join-Path $srcRootU ".claude\$d"
    if (-not (Test-Path $srcDir)) { continue }

    Get-ChildItem -Path $srcDir -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $rel = $_.FullName.Substring($srcRootU.Length).TrimStart('\')
        $target = Join-Path $destPath $rel
        if ($DryRun) {
            if (-not (Test-Path $target)) { Write-Host "   [dry] mkdir $target" -ForegroundColor DarkGray }
        } else {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
    }

    Get-ChildItem -Path $srcDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'README.md' -or $_.Name -like '_*.md' -or $_.Name -eq '.gitkeep' } |
        ForEach-Object {
            $rel = $_.FullName.Substring($srcRootU.Length).TrimStart('\')
            $target = Join-Path $destPath $rel
            if ($DryRun) {
                Write-Host "   [dry] $target" -ForegroundColor DarkGray
            } else {
                New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
                Copy-Item -Path $_.FullName -Destination $target -Force
            }
        }
}

# ============================================================================
# 完成
# ============================================================================

Write-Host ""
if ($DryRun) {
    Write-Host "✅ DRY-RUN 完成（未寫入任何檔案）" -ForegroundColor Green
} else {
    Write-Host "✅ 模板更新完成" -ForegroundColor Green
}
Write-Host ""
Write-Host "🔒 以下專案紀錄完全未被更動：" -ForegroundColor Yellow
foreach ($p in $preserveNote) { Write-Host "     - $p" }
Write-Host "     - (root) scripts/、.mcp.json.*.example（模板不再同步這兩者）"
if ($ClaudeOnly) {
    Write-Host "     - (root) 所有根層檔案（CLAUDE.md / .gitignore / .gitattributes 等）" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "🧹 舊版同步過來的 scripts/update-template.*、copy-template.*、check-counts.sh" -ForegroundColor Cyan
Write-Host "   與 .mcp.json.*.example 若不需要可手動刪除（本腳本不會刪，避免誤刪專案自己的檔案）"
Write-Host "   （check-counts.sh 已搬到 .claude/scripts/，會隨 .claude/ 一起同步）"
Write-Host "🧹 根目錄的 CLAUDE_TEMPLATE.md 已廢除，可直接刪除" -ForegroundColor Cyan
Write-Host "   （初始化狀態改看 .claude/taskmaster-data/project.json，留著它不會再有任何作用）"
Write-Host ""
if (-not $DryRun -and -not $NoBackup) {
    Write-Host "🛟 如需還原：解壓 .claude-backups\ 內最新的 zip 覆蓋回 .claude\" -ForegroundColor Cyan
}
if (-not $DryRun) {
    Write-Host ""
    Write-Host "👉 下一步：到目標專案開 Claude Code 跑一次 /task-status" -ForegroundColor Cyan
    Write-Host "   若 wbs.md 還是舊版面（沒有「現況」區），它會提議轉換成新版面（一次性遷移，長內容搬出不丟資料）"
    Write-Host "   專案圖解在開 session 時自動產生，/task-status 最後一行印畫面路徑；"
    Write-Host "   沒有架構文件時它會多印一行提示，說明怎麼請 documentation-specialist 反推草稿"
}
Write-Host ""

# robocopy 的成功碼(1-7)會讓 $LASTEXITCODE 非零，明確以 0 收尾避免呼叫端誤判失敗
exit 0
