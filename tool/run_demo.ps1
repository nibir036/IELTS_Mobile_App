# ---------------------------------------------------------------------------
# One double-click: start the AI service (nexted-ai, FastAPI) and the API
# server, open a public address for the API server, point the app at that
# address and build the APK.
#
# How a phone reaches everything:  phone -> https tunnel -> API server :4000
# -> AI service :8000 (on this computer only). The AI service never needs its
# own public address; the API server calls it locally.
#
# Everything here used to be four commands typed by hand, in order, in three
# windows - and the address changes every time the tunnel restarts, so getting
# one of them slightly wrong produced an app that opened on "couldn't reach
# the server" with nothing to say why.
#
# Run it from tool\RUN_DEMO.bat (double-click that file).
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$server = Join-Path $root 'server'
$envFile = Join-Path $root 'env.phone.json'

function Say([string]$text, [string]$colour = 'White') {
    Write-Host $text -ForegroundColor $colour
}

Say ''
Say '==========================================' Cyan
Say '  IELTS AI + Study abroad - demo build'    Cyan
Say '==========================================' Cyan
Say ''

function IsUp([string]$url) {
    try { Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing | Out-Null; return $true } catch { return $false }
}

# --- 0. the AI service (Study abroad AI) ------------------------------------
Say '[0/4] Starting the AI service (nexted-ai)...' Yellow
# It lives in this repo now (ai\); NEXTED_AI_DIR still overrides it.
$ai = $env:NEXTED_AI_DIR
if (-not $ai) { $ai = Join-Path $root 'ai' }
if (IsUp 'http://127.0.0.1:8000/health') {
    Say '      already running on http://127.0.0.1:8000' Green
} elseif (Test-Path (Join-Path $ai 'RUN_AI.bat')) {
    Start-Process cmd -ArgumentList '/k', "cd /d `"$ai`" && RUN_AI.bat" | Out-Null
    # The first start installs packages and downloads the embedding model.
    $aiUp = $false
    foreach ($i in 1..150) {
        Start-Sleep -Seconds 2
        if (IsUp 'http://127.0.0.1:8000/health') { $aiUp = $true; break }
    }
    if ($aiUp) { Say '      AI service is up on http://127.0.0.1:8000' Green }
    else {
        Say '      The AI service did not answer yet - look at its window.' Red
        Say '      The app still works; Study abroad AI uses the built-in fallback until it is up.' Gray
    }
} else {
    Say "      ai\RUN_AI.bat not found (set NEXTED_AI_DIR). Study abroad AI will use the built-in fallback." Gray
}

# --- 1. the API server ------------------------------------------------------
Say '[1/4] Starting the API server...' Yellow
if (-not (IsUp 'http://localhost:4000/health')) {
    Start-Process powershell -ArgumentList '-NoExit', '-Command', "cd `"$server`"; npx prisma migrate deploy; npx prisma generate; npm run dev" | Out-Null
}

# Wait until it actually answers, rather than assuming it is up.
$up = $false
foreach ($i in 1..40) {
    Start-Sleep -Seconds 2
    try {
        Invoke-WebRequest -Uri 'http://localhost:4000/health' -TimeoutSec 3 -UseBasicParsing | Out-Null
        $up = $true
        break
    } catch { }
}
if (-not $up) {
    Say ''
    Say 'The server did not start.' Red
    Say 'Look at the window that just opened - it will say why.' Red
    Say 'The usual cause is PostgreSQL being switched off.' Gray
    Say ''
    exit 1
}
Say '      server is up on http://localhost:4000' Green

# --- 2. the public address --------------------------------------------------
Say '[2/4] Opening a public address (cloudflared)...' Yellow
$log = Join-Path $env:TEMP 'nexted-tunnel.log'
$out = Join-Path $env:TEMP 'nexted-tunnel.out'
Remove-Item $log, $out -ErrorAction SilentlyContinue

try {
    Start-Process cloudflared `
        -ArgumentList 'tunnel', '--url', 'http://localhost:4000' `
        -RedirectStandardError $log -RedirectStandardOutput $out -WindowStyle Minimized | Out-Null
} catch {
    Say ''
    Say 'cloudflared was not found.' Red
    Say 'Install it once, then run this file again.' Gray
    Say ''
    exit 1
}

$url = $null
foreach ($i in 1..45) {
    Start-Sleep -Seconds 2
    foreach ($f in @($log, $out)) {
        if (Test-Path $f) {
            $hit = Select-String -Path $f -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' |
                   Select-Object -First 1
            if ($hit) { $url = $hit.Matches[0].Value; break }
        }
    }
    if ($url) { break }
}
if (-not $url) {
    Say ''
    Say 'No public address came back from cloudflared.' Red
    Say "Check $log" Gray
    Say ''
    exit 1
}
Say "      address: $url" Green

# --- 3. point the app at it -------------------------------------------------
# Three places, because a build can be made with or without the define file
# and all of them have to agree. Getting one wrong is what produced an APK
# that silently talked to yesterday's dead address.
Say '[3/4] Pointing the app at that address...' Yellow

$json = @"
{
  "_comment": "Written by tool/run_demo.ps1. The Cloudflare quick tunnel address lives only as long as that window stays open; this file is rewritten on every run.",
  "API_BASE_URL": "$url",
  "NEXTED_API_BASE_URL": "$url",
  "NEXTED_FORCE_ACCESS": "true"
}
"@
[IO.File]::WriteAllText($envFile, $json, (New-Object Text.UTF8Encoding $false))

foreach ($rel in @('lib\app\services\config.dart', 'lib\app\services\nexted_api.dart')) {
    $p = Join-Path $root $rel
    if (-not (Test-Path $p)) { continue }
    $t = [IO.File]::ReadAllText($p)
    $new = [Text.RegularExpressions.Regex]::Replace(
        $t, 'https://[a-z0-9-]+\.trycloudflare\.com', $url)
    if ($new -ne $t) { [IO.File]::WriteAllText($p, $new, (New-Object Text.UTF8Encoding $false)) }
}
Say '      env.phone.json and the two Dart defaults updated' Green

# --- 4. build ---------------------------------------------------------------
Say '[4/4] Building the APK (this takes 5-15 minutes)...' Yellow
Say ''
Push-Location $root
& flutter build apk --release --dart-define-from-file=env.phone.json
$code = $LASTEXITCODE
Pop-Location

$apk = Join-Path $root 'build\app\outputs\apk\release\app-release.apk'
Say ''
if ($code -ne 0 -or -not (Test-Path $apk)) {
    Say 'The build failed. The error is above.' Red
    Say ''
    exit 1
}

Say '==========================================' Green
Say '  Done.'                                    Green
Say '==========================================' Green
Say ''
Say 'APK:' White
Say "  $apk" Cyan
Say ''
Say 'Install it on the phone, then log in with:' White
Say '  01734519208  /  Demo@1234' Cyan
Say ''
Say 'KEEP THE WINDOWS THIS OPENED RUNNING (AI service, API server, tunnel).' Yellow
Say 'Close them, or shut the laptop, and the app loses the server.' Gray
Say ''
