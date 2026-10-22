@echo off
REM IELTS AI by nextED - one click: check PostgreSQL, create the ielts_ai
REM database and all tables, load all content + the demo account, then start
REM the API server on http://localhost:4000 in its own window.
REM Safe to run again (migrations already applied are skipped, content is upserted).
REM Everything is also written to tool\create_db_report.txt
setlocal
cd /d "%~dp0..\server"
set REPORT=%~dp0create_db_report.txt
echo IELTS AI database setup - %date% %time% > "%REPORT%"

echo ===== 0/5 Checking Node.js and PostgreSQL =====
where node >nul 2>nul
if errorlevel 1 (
  echo [FAIL] Node.js not found. Install Node.js 20+ from https://nodejs.org >> "%REPORT%"
  echo Node.js not found. Install Node.js 20+ from https://nodejs.org
  goto failed
)
for /f "delims=" %%v in ('node -v') do echo [OK] Node %%v >> "%REPORT%"

if not exist .env (
  echo [FAIL] server\.env is missing >> "%REPORT%"
  goto failed
)

REM Is a PostgreSQL service installed? Try to start it if it is stopped.
sc query state= all | findstr /I "postgresql" > "%TEMP%\pgsvc.txt"
if errorlevel 1 (
  echo [WARN] No PostgreSQL Windows service found. >> "%REPORT%"
) else (
  for /f "tokens=2 delims=:" %%s in ('findstr /I "SERVICE_NAME" "%TEMP%\pgsvc.txt"') do (
    echo [OK] PostgreSQL service:%%s >> "%REPORT%"
    net start %%s >> "%REPORT%" 2>&1
  )
)
powershell -NoProfile -Command "if ((Test-NetConnection localhost -Port 5432 -WarningAction SilentlyContinue).TcpTestSucceeded) { 'PORT5432=open' } else { 'PORT5432=closed' }" >> "%REPORT%"
powershell -NoProfile -Command "if ((Test-NetConnection localhost -Port 5433 -WarningAction SilentlyContinue).TcpTestSucceeded) { 'PORT5433=open' } else { 'PORT5433=closed' }" >> "%REPORT%"

echo ===== 1/5 Installing packages =====
echo. >> "%REPORT%"
echo ===== npm install ===== >> "%REPORT%"
call npm install >> "%REPORT%" 2>&1
if errorlevel 1 goto failed

echo ===== 2/5 Creating the database and tables =====
echo. >> "%REPORT%"
echo ===== prisma migrate deploy ===== >> "%REPORT%"
call npx prisma migrate deploy >> "%REPORT%" 2>&1
if errorlevel 1 goto failed

echo ===== 3/5 Preparing the database client =====
echo. >> "%REPORT%"
echo ===== prisma generate ===== >> "%REPORT%"
call npx prisma generate >> "%REPORT%" 2>&1
if errorlevel 1 goto failed

echo ===== 4/5 Loading content (a minute or two) =====
echo. >> "%REPORT%"
echo ===== prisma db seed ===== >> "%REPORT%"
call npx prisma db seed >> "%REPORT%" 2>&1
if errorlevel 1 goto failed

echo ===== 5/5 Starting the API server =====
echo. >> "%REPORT%"
echo [DONE] Database ready. Starting server window. >> "%REPORT%"
start "IELTS AI API server" cmd /k "cd /d "%~dp0..\server" && node scripts\env-sync.js && npm run dev"
echo.
echo Database is ready. The server is starting in a new window:
echo   http://localhost:4000/health
echo Keep that window open while you use the app.
echo Report: tool\create_db_report.txt
timeout /t 15
exit /b 0

:failed
echo [FAILED] See the lines above. >> "%REPORT%"
echo.
echo Something failed. Details are in tool\create_db_report.txt
timeout /t 30
exit /b 1
