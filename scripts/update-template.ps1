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

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Destination,

    [switch]$DryRun,     # 只列出將變更的內容，不實際寫入
    [switch]$Prune,      # 對 SYNC 目錄使用 /MIR，刪除目標多出來的檔（預設僅新增/覆蓋）
    [switch]$NoBackup    # 略過備份（預設會先把目標 .claude 壓成 zip）
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
    'output-styles', 'plugins', 'templates', 'ui', 'scripts', 'custom-rule&skill'
)
$syncClaudeFiles = @(
    'statusline.sh', 'statusline-debug.sh', 'statusline-linux.sh',
    'settings.json', 'README.md'
)
$syncRootDirs  = @('scripts')   # 倉庫根目錄下的輔助腳本（含本腳本自己）
$syncRootFiles = @(
    '.mcp.json.linux.example', '.mcp.json.windows.example',
    'CLAUDE_TEMPLATE.md', '.gitattributes'
)

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
Write-Host ""
Write-Host "🔄 更新模板資產 [$mode]" -ForegroundColor Cyan
Write-Host "   來源: $source"
Write-Host "   目標: $destPath"
Write-Host ""

Write-Host "▶ SYNC 模板目錄..." -ForegroundColor Green
foreach ($d in $syncClaudeDirs) {
    Invoke-Sync (Join-Path $source ".claude\$d") (Join-Path $destPath ".claude\$d") -Mirror:$Prune
}
foreach ($d in $syncRootDirs) {
    Invoke-Sync (Join-Path $source $d) (Join-Path $destPath $d) -Mirror:$Prune
}

Write-Host "▶ SYNC 模板檔案..." -ForegroundColor Green
foreach ($f in $syncClaudeFiles) {
    Copy-OneFile (Join-Path $source ".claude\$f") (Join-Path $destPath ".claude\$f")
}
foreach ($f in $syncRootFiles) {
    Copy-OneFile (Join-Path $source $f) (Join-Path $destPath $f)
}

Write-Host "▶ MERGE 骨架目錄（保留執行資料）..." -ForegroundColor Green
foreach ($d in $mergeClaudeDirs) {
    # AdditiveOnly：永不刪除目標已有的報告 / handoff
    Invoke-Sync (Join-Path $source ".claude\$d") (Join-Path $destPath ".claude\$d") -AdditiveOnly
}

Write-Host "▶ SEED 預設設定檔（僅在缺檔時建立，不覆蓋已選樣式）..." -ForegroundColor Green
$seedSrc = Join-Path $source '.claude\templates\statusline.conf.template'
$seedDst = Join-Path $destPath '.claude\taskmaster-data\statusline.conf'
if ((Test-Path $seedSrc) -and -not (Test-Path $seedDst)) {
    if ($DryRun) {
        Write-Host "   [dry] $seedDst"
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $seedDst) -Force | Out-Null
        Copy-Item -Path $seedSrc -Destination $seedDst -Force
        Write-Host "   建立 statusline.conf（預設 segmented）"
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
Write-Host ""
if (-not $DryRun -and -not $NoBackup) {
    Write-Host "🛟 如需還原：解壓 .claude-backups\ 內最新的 zip 覆蓋回 .claude\" -ForegroundColor Cyan
}
Write-Host ""

# robocopy 的成功碼(1-7)會讓 $LASTEXITCODE 非零，明確以 0 收尾避免呼叫端誤判失敗
exit 0
