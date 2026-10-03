@echo off
REM IELTS AI by nextED - update the database tables and load all content.
REM Applies new migrations (no reset, existing data is kept), then upserts
REM seed\data\*.json: demo content, question banks, full tests, guides,
REM resources, translations, config and the demo account.
REM Safe to run again. Results are saved to tool\seed_report.txt
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

echo ===== 1/4 Installing packages =====
call npm install
if errorlevel 1 goto failed

echo.
echo ===== 2/4 Applying database migrations =====
call npx prisma migrate deploy
if errorlevel 1 goto failed

echo.
echo ===== 3/4 Updating the database client =====
call npx prisma generate
if errorlevel 1 goto failed

echo.
echo ===== 4/4 Loading content (takes a minute or two) =====
echo ===== prisma migrate status ===== > ..\tool\seed_report.txt
call npx prisma migrate status >> ..\tool\seed_report.txt 2>&1
echo. >> ..\tool\seed_report.txt
echo ===== prisma db seed ===== >> ..\tool\seed_report.txt
call npx prisma db seed >> ..\tool\seed_report.txt 2>&1
if errorlevel 1 (
  type ..\tool\seed_report.txt
  goto failed
)
type ..\tool\seed_report.txt

echo.
echo Done. Results saved to tool\seed_report.txt
echo To browse the tables: cd server ^&^& npx prisma studio
pause
exit /b 0

:failed
echo.
echo Something failed above. Send tool\seed_report.txt (or the red lines) to Claude.
pause
exit /b 1
