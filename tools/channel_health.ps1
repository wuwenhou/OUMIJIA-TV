# CHANNEL HEALTH CHECK — OUMIJIA TV
#
# Kiểm tra thực tế từng nguồn phát (không tin HTTP 200):
#   1. Tải playlist (m3u8) — xác nhận đúng #EXTM3U
#   2. Nếu là master playlist → đi theo variant đầu tiên
#   3. Tải đoạn media đầu tiên (EXT-X-MAP với fMP4, hoặc segment TS đầu)
#   4. Kiểm tra chữ ký container: TS (0x47) / fMP4 (ftyp, styp, moof)
#
# Phân loại: WORKING / DEGRADED / OFFLINE / INVALID / UNVERIFIED
# - Có rate-limit giữa các kênh (mặc định 700ms), timeout từng request.
# - Cache kết quả 6 giờ khi dùng -UseCache.
# - Xuất tools/reports/channel-health.{json,html}
#
# Cách dùng:
#   powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1
#   powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1 -M3uPath https://iptv-org.github.io/iptv/countries/vn.m3u -ReportName candidates
#   powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1 -UpdateConfig
#
# Lưu ý: đây là kiểm tra hạ tầng mạng + container, KHÔNG thay thế kiểm thử
# giải mã hình/tiếng trên thiết bị thật. Báo cáo ghi rõ phần chưa kiểm chứng.

param(
    [string]$M3uPath = "",
    [string]$ConfigPath = "config/channels.json",
    [string]$OutDir = "tools/reports",
    [string]$ReportName = "channel-health",
    [int]$TimeoutSec = 12,
    [int]$MaxChannels = 0,
    [int]$DelayMs = 700,
    [switch]$UseCache,
    [switch]$UpdateConfig
)

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Net.Http

$script:Ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36"
$script:CachePath = Join-Path $OutDir "health-cache.json"
$script:CacheTtlHours = 6

function Get-UrlBytes {
    param(
        [string]$Url,
        [hashtable]$Headers = @{},
        [int]$MaxBytes = 524288
    )
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Url)
        $req.Headers.TryAddWithoutValidation("User-Agent", $script:Ua) | Out-Null
        foreach ($k in $Headers.Keys) {
            $req.Headers.TryAddWithoutValidation([string]$k, [string]$Headers[$k]) | Out-Null
        }
        $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $status = [int]$resp.StatusCode
        $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $buffer = New-Object byte[] $MaxBytes
        $total = 0
        while ($total -lt $MaxBytes) {
            $read = $stream.Read($buffer, $total, [Math]::Min(8192, $MaxBytes - $total))
            if ($read -le 0) { break }
            $total += $read
        }
        $bytes = New-Object byte[] $total
        if ($total -gt 0) { [Array]::Copy($buffer, $bytes, $total) }
        return [pscustomobject]@{ Status = $status; Bytes = $bytes; Error = "" }
    }
    catch {
        return [pscustomobject]@{ Status = -1; Bytes = (New-Object byte[] 0); Error = $_.Exception.Message }
    }
    finally {
        $client.Dispose()
    }
}

function Resolve-PlaylistUrl {
    param([string]$Base, [string]$Relative)
    if ($Relative -match '^https?://') { return $Relative }
    try {
        return ([System.Uri]::new([System.Uri]$Base, $Relative)).AbsoluteUri
    }
    catch {
        return $Relative
    }
}

function Get-ContainerSignature {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ge 1 -and $Bytes[0] -eq 0x47) { return "TS" }
    if ($Bytes.Length -ge 8) {
        $tag = [System.Text.Encoding]::ASCII.GetString($Bytes, 4, 4)
        if ($tag -eq "ftyp" -or $tag -eq "styp" -or $tag -eq "moof") { return "fMP4" }
    }
    $probe = [System.Text.Encoding]::ASCII.GetString($Bytes, 0, [Math]::Min(2048, $Bytes.Length))
    if ($probe -match "ftyp|moof|styp") { return "fMP4" }
    return "UNKNOWN"
}

function Get-PlaylistFirstVariant {
    param([string]$Text, [string]$BaseUrl)
    $lines = $Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith("#EXT-X-STREAM-INF")) {
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if (-not $lines[$j].StartsWith("#")) {
                    return (Resolve-PlaylistUrl -Base $BaseUrl -Relative $lines[$j])
                }
            }
        }
    }
    return ""
}

function Get-PlaylistFirstSegment {
    param([string]$Text, [string]$BaseUrl)
    $mapMatch = [regex]::Match($Text, '#EXT-X-MAP:[^\r\n]*URI="([^"]+)"')
    if ($mapMatch.Success) {
        return (Resolve-PlaylistUrl -Base $BaseUrl -Relative $mapMatch.Groups[1].Value)
    }
    $lines = $Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    foreach ($line in $lines) {
        if ($line.StartsWith("#EXT-X-STREAM-INF")) { continue }
        if (-not $line.StartsWith("#")) {
            return (Resolve-PlaylistUrl -Base $BaseUrl -Relative $line)
        }
    }
    return ""
}

function Test-StreamUrl {
    param([string]$Url, [hashtable]$Headers = @{})

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = [pscustomobject]@{
        status    = "INVALID"
        detail    = ""
        latencyMs = 0
        testedUrl = $Url
        container = ""
    }

    if ([string]::IsNullOrWhiteSpace($Url)) {
        $result.detail = "URL rỗng"
        return $result
    }
    try { [void][System.Uri]::new($Url) }
    catch {
        $result.detail = "URL không hợp lệ"
        return $result
    }

    $resp = Get-UrlBytes -Url $Url -Headers $Headers -MaxBytes 524288
    if ($resp.Status -lt 200 -or $resp.Status -ge 400) {
        $result.status = "OFFLINE"
        $result.detail = if ($resp.Error) { "Lỗi kết nối: $($resp.Error)" } else { "HTTP $($resp.Status)" }
        $result.latencyMs = [int]$sw.ElapsedMilliseconds
        return $result
    }

    $text = [System.Text.Encoding]::UTF8.GetString($resp.Bytes)
    $isPlaylist = $text.TrimStart().StartsWith("#EXTM3U")

    if ($isPlaylist) {
        # master playlist → chọn variant đầu tiên
        $variant = Get-PlaylistFirstVariant -Text $text -BaseUrl $Url
        if ($variant) {
            $vResp = Get-UrlBytes -Url $variant -Headers $Headers -MaxBytes 524288
            if ($vResp.Status -lt 200 -or $vResp.Status -ge 400) {
                $result.status = "OFFLINE"
                $result.detail = "Variant không tải được (HTTP $($vResp.Status))"
                $result.latencyMs = [int]$sw.ElapsedMilliseconds
                return $result
            }
            $text = [System.Text.Encoding]::UTF8.GetString($vResp.Bytes)
            $Url = $variant
            $result.testedUrl = $variant
        }

        $segment = Get-PlaylistFirstSegment -Text $text -BaseUrl $Url
        if ([string]::IsNullOrWhiteSpace($segment)) {
            $result.status = "INVALID"
            $result.detail = "Playlist không có segment/variant"
            $result.latencyMs = [int]$sw.ElapsedMilliseconds
            return $result
        }

        $segResp = Get-UrlBytes -Url $segment -Headers $Headers -MaxBytes 98304
        if ($segResp.Status -lt 200 -or $segResp.Status -ge 400 -or $segResp.Bytes.Length -eq 0) {
            $result.status = "OFFLINE"
            $result.detail = "Playlist OK nhưng segment lỗi (HTTP $($segResp.Status))"
            $result.latencyMs = [int]$sw.ElapsedMilliseconds
            return $result
        }

        $container = Get-ContainerSignature -Bytes $segResp.Bytes
        $result.container = $container
        if ($container -eq "UNKNOWN") {
            $result.status = "DEGRADED"
            $result.detail = "Segment tải được nhưng không nhận diện container"
        }
        else {
            $result.status = "WORKING"
            $result.detail = "Playlist + segment $container hợp lệ"
        }
    }
    else {
        # Không phải m3u8 → thử coi là file media trực tiếp
        if ($resp.Bytes.Length -eq 0) {
            $result.status = "INVALID"
            $result.detail = "Nội dung rỗng"
        }
        else {
            $container = Get-ContainerSignature -Bytes $resp.Bytes
            $result.container = $container
            if ($container -eq "UNKNOWN") {
                $result.status = "DEGRADED"
                $result.detail = "File media không nhận diện container"
            }
            else {
                $result.status = "WORKING"
                $result.detail = "File media $container hợp lệ"
            }
        }
    }

    $result.latencyMs = [int]$sw.ElapsedMilliseconds
    if ($result.status -eq "WORKING" -and $result.latencyMs -gt 6000) {
        $result.status = "DEGRADED"
        $result.detail = "$($result.detail); phản hồi chậm $($result.latencyMs)ms"
    }
    return $result
}

function Read-M3uCandidates {
    param([string]$Source)
    if ($Source -match '^https?://') {
        $resp = Get-UrlBytes -Url $Source -Headers @{} -MaxBytes 1048576
        $text = [System.Text.Encoding]::UTF8.GetString($resp.Bytes)
    }
    else {
        $text = [System.IO.File]::ReadAllText((Resolve-Path $Source), [System.Text.Encoding]::UTF8)
    }
    $lines = $text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $items = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].StartsWith("#EXTINF")) { continue }
        $meta = $lines[$i]
        $name = ($meta -split ",", 2)[1]
        if (-not $name) { $name = "Không tên" }
        $logo = ""
        $group = ""
        $id = ""
        $m = [regex]::Match($meta, 'tvg-logo="([^"]*)"')
        if ($m.Success) { $logo = $m.Groups[1].Value }
        $m = [regex]::Match($meta, 'group-title="([^"]*)"')
        if ($m.Success) { $group = $m.Groups[1].Value }
        $m = [regex]::Match($meta, 'tvg-id="([^"]*)"')
        if ($m.Success) { $id = $m.Groups[1].Value }

        $url = ""
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j].StartsWith("#EXTINF")) { break }
            if (-not $lines[$j].StartsWith("#")) { $url = $lines[$j]; break }
        }
        if ($url) {
            $items += [pscustomobject]@{
                id      = $id
                name    = $name
                logo    = $logo
                group   = $group
                primary = $url
                fallback = @()
                headers = @{}
            }
        }
    }
    return $items
}

# ---------------- nạp danh sách ----------------
if ($M3uPath) {
    $channels = @(Read-M3uCandidates -Source $M3uPath)
    $mode = "m3u"
}
else {
    $json = [System.IO.File]::ReadAllText((Resolve-Path $ConfigPath), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $channels = @($json.channels)
    $mode = "config"
}

if ($MaxChannels -gt 0) { $channels = @($channels | Select-Object -First $MaxChannels) }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# ---------------- cache 6h ----------------
$cache = @{}
if ($UseCache -and (Test-Path $script:CachePath)) {
    try {
        $raw = [System.IO.File]::ReadAllText($script:CachePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
    }
    catch { $cache = @{} }
}

Write-Host "Kiem tra $($channels.Count) kenh ($mode) ..."
$items = @()
$index = 0

foreach ($ch in $channels) {
    $index++
    $headers = @{}
    if ($ch.headers) {
        if ($ch.headers -is [hashtable]) {
            foreach ($k in $ch.headers.Keys) { $headers[$k] = $ch.headers[$k] }
        }
        else {
            foreach ($p in $ch.headers.PSObject.Properties) { $headers[$p.Name] = $p.Value }
        }
    }
    $urls = @($ch.primary) + @($ch.fallback | Where-Object { $_ })
    $urls = @($urls | Where-Object { $_ })
    $best = $null
    $usedFallback = $false
    $tested = @()

    for ($u = 0; $u -lt $urls.Count; $u++) {
        $url = [string]$urls[$u]
        $cached = $cache[$url]
        if ($cached) {
            $checked = [datetime]::Parse($cached.checkedAt)
            if (((Get-Date) - $checked).TotalHours -lt $script:CacheTtlHours) {
                $best = [pscustomobject]@{
                    status = $cached.status; detail = $cached.detail
                    latencyMs = $cached.latencyMs; testedUrl = $url; container = $cached.container
                }
            }
        }
        if (-not $best) { $best = Test-StreamUrl -Url $url -Headers $headers }

        $tested += [pscustomobject]@{
            url = $url; status = $best.status; detail = $best.detail; latencyMs = $best.latencyMs
        }
        if ($best.status -eq "WORKING") { if ($u -gt 0) { $usedFallback = $true }; break }
        if ($u -eq 0 -and $urls.Count -gt 1) { $best = $null }
    }
    if (-not $best) {
        $best = [pscustomobject]@{ status = "INVALID"; detail = "Không có URL"; latencyMs = 0; testedUrl = ""; container = "" }
    }

    $item = [pscustomobject]@{
        id            = if ($ch.id) { $ch.id } else { "" }
        name          = $ch.name
        group         = if ($ch.group) { $ch.group } else { "" }
        logo          = if ($ch.logo) { $ch.logo } else { "" }
        status        = $best.status
        detail        = $best.detail
        latencyMs     = $best.latencyMs
        container     = $best.container
        testedUrl     = $best.testedUrl
        usedFallback  = $usedFallback
        checkedAt     = (Get-Date).ToString("o")
        urls          = $tested
    }
    $items += $item
    Write-Host ("[{0}/{1}] {2} -> {3} ({4}ms)" -f $index, $channels.Count, $ch.name, $best.status, $best.latencyMs)
    Start-Sleep -Milliseconds $DelayMs
}

# ---------------- tổng hợp ----------------
$working = @($items | Where-Object { $_.status -eq "WORKING" }).Count
$degraded = @($items | Where-Object { $_.status -eq "DEGRADED" }).Count
$offline = @($items | Where-Object { $_.status -eq "OFFLINE" }).Count
$invalid = @($items | Where-Object { $_.status -eq "INVALID" }).Count

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    mode        = $mode
    source      = if ($M3uPath) { $M3uPath } else { $ConfigPath }
    summary     = [pscustomobject]@{
        total    = $items.Count
        working  = $working
        degraded = $degraded
        offline  = $offline
        invalid  = $invalid
    }
    note        = "Kiem tra playlist + segment dau tien (container signature). Khong thay the kiem thu giai ma tren thiet bi that."
    channels    = $items
}

$jsonPath = Join-Path $OutDir "$ReportName.json"
$htmlPath = Join-Path $OutDir "$ReportName.html"
[System.IO.File]::WriteAllText($jsonPath, ($report | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))

# lưu cache
$newCache = @{}
foreach ($it in $items) {
    foreach ($u in $it.urls) {
        $newCache[$u.url] = [pscustomobject]@{
            status = $u.status; detail = $u.detail; latencyMs = $u.latencyMs
            container = $it.container; checkedAt = $it.checkedAt
        }
    }
}
[System.IO.File]::WriteAllText($script:CachePath, ($newCache | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))

# ---------------- HTML ----------------
$rows = foreach ($it in $items) {
    $color = switch ($it.status) {
        "WORKING" { "#1f9d55" }
        "DEGRADED" { "#b7791f" }
        "OFFLINE" { "#c53030" }
        "INVALID" { "#c53030" }
        default { "#4a5568" }
    }
    "<tr><td>$([System.Net.WebUtility]::HtmlEncode($it.name))</td><td>$([System.Net.WebUtility]::HtmlEncode($it.group))</td>" +
    "<td><span style='color:$color;font-weight:700'>$($it.status)</span><br><small>$([System.Net.WebUtility]::HtmlEncode($it.detail))</small></td>" +
    "<td>$($it.latencyMs) ms</td><td><small>$([System.Net.WebUtility]::HtmlEncode($it.testedUrl))</small></td></tr>"
}
$html = @"
<!doctype html>
<html lang="vi"><head><meta charset="utf-8">
<title>OUMIJIA TV - Channel Health</title>
<style>
body{background:#0b0f14;color:#f4f7fa;font-family:Segoe UI,Roboto,Arial,sans-serif;padding:24px}
h1{font-size:22px;margin:0 0 4px}p{color:#9aa8b5;margin:0 0 18px}
.badges span{display:inline-block;padding:6px 12px;border-radius:8px;margin-right:8px;font-weight:700}
table{border-collapse:collapse;width:100%;font-size:13px}
th,td{border-bottom:1px solid #25303c;padding:8px 10px;text-align:left;vertical-align:top}
th{color:#9aa8b5;font-weight:600}small{color:#66737f;word-break:break-all}
</style></head><body>
<h1>OUMIJIA TV — Channel Health Report</h1>
<p>Tạo lúc $($report.generatedAt) · Nguồn: $([System.Net.WebUtility]::HtmlEncode($report.source))</p>
<div class="badges">
<span style="color:#39d98a">WORKING: $working</span>
<span style="color:#f5a623">DEGRADED: $degraded</span>
<span style="color:#ff6b6b">OFFLINE: $offline</span>
<span style="color:#ff6b6b">INVALID: $invalid</span>
</div>
<p style="margin-top:16px">$($report.note)</p>
<table><thead><tr><th>Kênh</th><th>Nhóm</th><th>Trạng thái</th><th>Độ trễ</th><th>URL đã kiểm tra</th></tr></thead>
<tbody>$($rows -join "`n")</tbody></table>
</body></html>
"@
[System.IO.File]::WriteAllText($htmlPath, $html, (New-Object System.Text.UTF8Encoding($false)))

# ---------------- cập nhật config (tuỳ chọn) ----------------
if ($UpdateConfig -and $mode -eq "config") {
    $checkedAt = (Get-Date).ToString("yyyy-MM-dd")
    foreach ($ch in $json.channels) {
        $match = $items | Where-Object { $_.id -eq $ch.id } | Select-Object -First 1
        if ($match) {
            $ch | Add-Member -NotePropertyName health -NotePropertyValue $match.status -Force
            $ch | Add-Member -NotePropertyName lastVerified -NotePropertyValue $checkedAt -Force
        }
    }
    $json | Add-Member -NotePropertyName updated -NotePropertyValue $checkedAt -Force
    [System.IO.File]::WriteAllText((Resolve-Path $ConfigPath), ($json | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Da cap nhat health/lastVerified vao $ConfigPath"
}

Write-Host ""
Write-Host "Ket qua: WORKING=$working DEGRADED=$degraded OFFLINE=$offline INVALID=$invalid"
Write-Host "JSON: $jsonPath"
Write-Host "HTML: $htmlPath"
