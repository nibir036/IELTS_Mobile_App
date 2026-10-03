@echo off
REM IELTS AI by nextED - start the API server for the Flutter app.
REM First run: installs packages, adds the new settings to server\.env,
REM applies database migrations. Then starts the server on http://localhost:4000
cd /d "%~dp0..\server"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Install Node.js 20 or newer from https://nodejs.org and run this again.
  pause
  exit /b 1
)
if not exist .env (
  echo server\.env is missing. Run tool\setup_db.bat first.
  pause
  exit /b 1
)

echo ===== 1/3 Installing packages =====
call npm install
if errorlevel 1 goto failed

echo.
echo ===== 2/3 Settings and database =====
node scripts\env-sync.js
if errorlevel 1 goto failed
call npx prisma migrate dev --name api_v1
if errorlevel 1 goto failed

echo.
echo ===== 3/3 Starting the API server (Ctrl+C to stop) =====
echo Health check: http://localhost:4000/health
call npm run dev
goto end

:failed
echo.
echo Something failed above. Copy the red lines and send them to Claude.
pause
exit /b 1

:end
