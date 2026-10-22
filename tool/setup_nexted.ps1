# One-time setup for the database and the nexted.app module.
#
#   Creates server\.env, writes your PostgreSQL password into it, installs the
#   server's packages, creates the "ielts_ai" database with every table,
#   loads the IELTS content and the nexted.app starter catalogue.
#
# Run it by double-clicking tool\setup_nexted.bat. Safe to run again.

$ErrorActionPreference = 'Stop'

function Step($text) {
    Write-Host ''
    Write-Host "== $text" -ForegroundColor Cyan
}

function Fail($text) {
    Write-Host ''
    Write-Host "!! $text" -ForegroundColor Red
    Write-Host ''
    exit 1
}

$root   = Split-Path -Parent $PSScriptRoot
$server = Join-Path $root 'server'
if (-not (Test-Path $server)) { Fail "Can't find the server folder at $server" }
Set-Location $server

Write-Host ''
Write-Host 'IELTS AI + nexted.app - database setup' -ForegroundColor White
Write-Host "Project: $root"

# ── 1. node ──────────────────────────────────────────────────────────────────
Step 'Checking Node.js'
try { $nodeVersion = (& node --version) } catch { $nodeVersion = $null }
if (-not $nodeVersion) { Fail 'Node.js is not installed, or not on PATH. Install Node 20+ from nodejs.org and run this again.' }
Write-Host "Node $nodeVersion"

# ── 2. server\.env ───────────────────────────────────────────────────────────
Step 'Settings file (server\.env)'
$envFile = Join-Path $server '.env'
$staged  = Join-Path $server 'env-setup.txt'
$example = Join-Path $server '.env.example'

if (-not (Test-Path $envFile)) {
    if (Test-Path $staged) {
        Rename-Item -Path $staged -NewName '.env'
        Write-Host 'Created server\.env'
    } elseif (Test-Path $example) {
        Copy-Item $example $envFile
        Write-Host 'Created server\.env from .env.example'
    } else {
        Fail 'No .env, env-setup.txt or .env.example found in the server folder.'
    }
} else {
    Write-Host 'server\.env is already there - keeping it.'
}

# ── 3. password ──────────────────────────────────────────────────────────────
$text = Get-Content $envFile -Raw
if ($text -match 'PUT_YOUR_POSTGRES_PASSWORD_HERE' -or $text -match 'YOUR_PASSWORD') {
    Step 'PostgreSQL password'
    Write-Host 'The password of the "postgres" user you set when installing PostgreSQL.'
    $pw = Read-Host 'Password (press Enter to use: postgres)'
    if ([string]::IsNullOrWhiteSpace($pw)) { $pw = 'postgres' }
    # URL-encode it, so @ # : / % in the password don't break the connection string.
    $encoded = [uri]::EscapeDataString($pw)
    $text = $text.Replace('PUT_YOUR_POSTGRES_PASSWORD_HERE', $encoded).Replace('YOUR_PASSWORD', $encoded)
    Set-Content -Path $envFile -Value $text -NoNewline -Encoding UTF8
    Write-Host 'Password written to server\.env (it never leaves your computer).'
} else {
    Write-Host 'The password is already filled in.'
}

# ── 4. packages ──────────────────────────────────────────────────────────────
Step 'Installing the server packages (a few minutes the first time)'
& npm install
if ($LASTEXITCODE -ne 0) { Fail 'npm install failed. Check your internet connection and try again.' }

# ── 5. database + tables ─────────────────────────────────────────────────────
Step 'Creating the ielts_ai database and its tables'
Write-Host 'This creates a NEW database called ielts_ai. Your other databases are not touched.'
& npx prisma migrate deploy
if ($LASTEXITCODE -ne 0) {
    Fail @'
The migration failed. The usual reasons:
  - PostgreSQL is not running (check Services, "postgresql-x64-…").
  - The password in server\.env is wrong - open the file and fix DATABASE_URL.
  - PostgreSQL is on another port (5433 instead of 5432) - change it in DATABASE_URL.
'@
}

# ── 6. content ───────────────────────────────────────────────────────────────
Step 'Loading the IELTS content (question banks, guides, demo account)'
& npx prisma db seed
if ($LASTEXITCODE -ne 0) { Write-Host 'Seeding failed - the app will still run, but with no content yet.' -ForegroundColor Yellow }

Step 'Loading the nexted.app starter catalogue (courses and scholarships)'
& npx tsx --env-file=.env scripts/nexted-catalogue.ts
if ($LASTEXITCODE -ne 0) { Write-Host 'Catalogue loading failed - course matching will show "No courses loaded yet".' -ForegroundColor Yellow }

# ── done ─────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Done. The database is ready.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next:'
Write-Host '  1. Start the server:   cd server   then   npm run dev'
Write-Host '     Check it: open http://localhost:4000/health'
Write-Host '  2. Run the app:        flutter run -d emulator-5554 --dart-define-from-file=env.json'
Write-Host '  3. Log in with the demo account:  phone 1734519208   password Demo@1234'
Write-Host ''
Write-Host 'The AI counsellor, course matching and scholarship finder also need a'
Write-Host 'GEMINI_API_KEY in server\.env (get one at https://aistudio.google.com/apikey).'
Write-Host ''

$start = Read-Host 'Start the server now? (Y/n)'
if ([string]::IsNullOrWhiteSpace($start) -or $start -match '^[Yy]') {
    Write-Host ''
    Write-Host 'Starting the API server. Press Ctrl+C to stop it.' -ForegroundColor Cyan
    & npm run dev
}
