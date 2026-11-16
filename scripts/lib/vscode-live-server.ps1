# vscode-live-server.ps1 — 讓 Live Server 忽略專案地圖資料夾（copy-template.ps1、update-template.ps1 dot-source 共用）
#
# 規則與 vscode-live-server.sh 一致（那份是唯一來源，改規則兩份一起改）。
# 註解檢查必須在 ConvertFrom-Json 之前：PowerShell 7 的 ConvertFrom-Json 會吞掉註解，
# 改寫後註解就消失了。誤判方向只會變成印手動那行。

$script:LiveServerGlob = '.claude/taskmaster-data/overview/**'
$script:LiveServerKey = 'liveServer.settings.ignoreFiles'
$script:LiveServerDefaults = @('.vscode/**', '**/*.scss', '**/*.sass')

function Ensure-LiveServerIgnore {
    param([string]$Root, [switch]$DryRun)
    $glob = $script:LiveServerGlob; $key = $script:LiveServerKey
    $f = Join-Path $Root '.vscode\settings.json'
    $manual = "   ⚠ .vscode/settings.json 有註解或不是標準 JSON，沒有自動修改。請手動加入：`"$key`": [`"$glob`"]（已有這個鍵就把字串加進陣列）"
    $utf8 = New-Object System.Text.UTF8Encoding $false

    if (-not (Test-Path -LiteralPath $f)) {
        if ($DryRun) { Write-Host "   [dry] 會建立 $f（Live Server 忽略專案地圖資料夾）" -ForegroundColor DarkGray; return }
        New-Item -ItemType Directory -Path (Join-Path $Root '.vscode') -Force | Out-Null
        $obj = [ordered]@{}
        $obj[$key] = @($script:LiveServerDefaults + $glob)
        [System.IO.File]::WriteAllText($f, (($obj | ConvertTo-Json -Depth 100) + "`n"), $utf8)
        Write-Host "   ✚ 已建立 .vscode/settings.json（Live Server 忽略專案地圖資料夾）" -ForegroundColor Cyan
        return
    }

    $text = [System.IO.File]::ReadAllText($f, $utf8)
    if ($text -match '(?m)(^|[\s,{\[])//' -or $text.Contains('/*')) { Write-Host $manual -ForegroundColor Yellow; return }
    try { $json = $text | ConvertFrom-Json -ErrorAction Stop } catch { Write-Host $manual -ForegroundColor Yellow; return }
    if ($null -eq $json -or $json -isnot [System.Management.Automation.PSCustomObject]) { Write-Host $manual -ForegroundColor Yellow; return }

    $prop = $json.PSObject.Properties[$key]
    if ($prop -and $null -ne $prop.Value) {
        if ($prop.Value -isnot [System.Array]) {
            Write-Host "   ⚠ .vscode/settings.json 的 $key 不是陣列，沒有自動修改。請手動加入：`"$key`": [`"$glob`"]（把字串加進陣列）" -ForegroundColor Yellow
            return
        }
        if ($prop.Value -contains $glob) {
            Write-Host "   ✓ .vscode/settings.json 已設定 Live Server 忽略專案地圖資料夾" -ForegroundColor DarkGray
            return
        }
        $new = @($prop.Value) + $glob
    } else {
        $new = @($script:LiveServerDefaults + $glob)
    }
    if ($DryRun) { Write-Host "   [dry] 會在 $f 加上 $key 的 $glob" -ForegroundColor DarkGray; return }

    if ($prop) { $prop.Value = $new } else { $json | Add-Member -NotePropertyName $key -NotePropertyValue $new }
    $out = $json | ConvertTo-Json -Depth 100
    if ($text.Contains("`r`n")) { $out = $out -replace "`r?`n", "`r`n" }
    $tmp = "$f.tmp"
    [System.IO.File]::WriteAllText($tmp, $out + $(if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }), $utf8)
    Move-Item -LiteralPath $tmp -Destination $f -Force
    Write-Host "   ✚ 已更新 .vscode/settings.json（Live Server 忽略專案地圖資料夾）" -ForegroundColor Cyan
}
