# copy-template.ps1 — 將 claude_v2026 模板複製到新專案資料夾
# 自動排除個人設定、執行時資料、歷史紀錄等專案專屬內容
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\copy-template.ps1 -Destination D:\projects\my-app
#   或
#   .\scripts\copy-template.ps1 D:\projects\my-app

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Destination
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# 路徑設定
# ============================================================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Resolve-Path (Join-Path $scriptRoot '..')

# 禁止複製到自己
if ((Test-Path $Destination) -and ((Resolve-Path $Destination).Path -eq $source.Path)) {
    Write-Host "❌ 錯誤：目標資料夾不能是模板本身" -ForegroundColor Red
    exit 1
}

# ============================================================================
# 目標驗證
# ============================================================================

if ((Test-Path $Destination) -and (Get-ChildItem -Path $Destination -Force | Select-Object -First 1)) {
    Write-Host "⚠️  目標資料夾已存在且非空: $Destination" -ForegroundColor Yellow
    $answer = Read-Host "是否繼續覆蓋？[y/N]"
    if ($answer -notmatch '^[Yy]$') {
        Write-Host "已取消"
        exit 0
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

# ============================================================================
# 排除清單（Robocopy 用）
# ============================================================================

$excludeDirs = @(
    '.git',
    'node_modules',
    '.venv',
    'venv',
    '__pycache__',
    '.vscode',
    '.idea',
    'tmp',
    'workshop',
    # .claude 子目錄
    'taskmaster-data',
    'qa-history',
    'sessions',
    'logs',
    'worktrees',
    'context',
    'coordination'
)

$excludeFiles = @(
    'settings.local.json',
    '.env',
    '.env.local',
    '.mcp.json',
    '.DS_Store',
    'Thumbs.db',
    '*.pyc',
    '*.tmp',
    '*.bak'
)

# ============================================================================
# 執行複製（使用 Robocopy，Windows 原生且最快）
# ============================================================================

Write-Host ""
Write-Host "📦 複製模板..." -ForegroundColor Cyan
Write-Host "   來源: $source"
Write-Host "   目標: $Destination"
Write-Host ""

$robocopyArgs = @(
    "`"$source`"",
    "`"$Destination`"",
    '/E',           # 複製所有子目錄（含空目錄）
    '/R:1',         # 失敗重試 1 次
    '/W:1',         # 等待 1 秒
    '/NP',          # 不顯示百分比
    '/NDL',         # 不列出目錄
    '/NJH',         # 不顯示 job header
    '/NJS'          # 不顯示 job summary
)

foreach ($dir in $excludeDirs) {
    $robocopyArgs += '/XD'
    $robocopyArgs += "`"$dir`""
}

foreach ($file in $excludeFiles) {
    $robocopyArgs += '/XF'
    $robocopyArgs += "`"$file`""
}

# Robocopy 的 exit code：0-7 都算成功
$proc = Start-Process -FilePath 'robocopy' -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ge 8) {
    Write-Host "❌ Robocopy 失敗 (exit code: $($proc.ExitCode))" -ForegroundColor Red
    exit 1
}

# ============================================================================
# 後置處理
# ============================================================================

# 建立空的必要目錄
New-Item -ItemType Directory -Path (Join-Path $Destination '.claude\logs') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destination '.claude\taskmaster-data') -Force | Out-Null

# 建立最小化的 settings.local.json
$minimalSettings = @'
{
  "permissions": {
    "allow": []
  },
  "enableAllProjectMcpServers": true
}
'@
$minimalSettings | Set-Content -Path (Join-Path $Destination '.claude\settings.local.json') -Encoding UTF8

# ============================================================================
# 完成訊息
# ============================================================================

Write-Host ""
Write-Host "✅ 模板複製完成" -ForegroundColor Green
Write-Host ""
Write-Host "下一步:"
Write-Host "  cd `"$Destination`""
Write-Host ""
Write-Host "  # 1. 複製 MCP 設定範本"
Write-Host "  cp .mcp.json.windows.example .mcp.json"
Write-Host ""
Write-Host "  # 2. 填入 API keys 後啟動"
Write-Host "  claude"
Write-Host ""
Write-Host "  # 3. 初始化專案"
Write-Host "  /task-init"
Write-Host ""
