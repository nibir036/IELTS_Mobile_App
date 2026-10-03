@echo off
REM IELTS AI by nextED - create the PostgreSQL database, tables and seed data.
REM Run from anywhere: it switches to the server folder itself.
REM Safe to run again: migrations that already ran are skipped, seed rows are upserted.
cd /d "%~dp0..\server"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Install Node.js 20 or newer from https://nodejs.org and run this again.
  pause
  exit /b 1
)

if not exist .env (
  copy .env.example .env >nul
  echo.
  echo A new file server\.env was created.
  echo Notepad will open it now: replace YOUR_PASSWORD with your postgres password,
  echo check the port ^(5432 or 5433^), save and close Notepad.
  echo.
  pause
  notepad .env
)

echo.
echo ===== 1/3 Installing packages =====
call npm install
if errorlevel 1 goto failed

echo.
echo ===== 2/3 Creating the database and tables =====
call npx prisma migrate dev --name init --skip-seed
if errorlevel 1 goto failed

echo.
echo ===== 3/3 Loading seed data =====
echo ===== prisma migrate status ===== > ..\tool\db_report.txt
call npx prisma migrate status >> ..\tool\db_report.txt 2>&1
echo. >> ..\tool\db_report.txt
echo ===== prisma db seed ===== >> ..\tool\db_report.txt
call npx prisma db seed >> ..\tool\db_report.txt 2>&1
type ..\tool\db_report.txt

echo.
echo Done. Results saved to tool\db_report.txt
echo To browse the tables: cd server ^&^& npx prisma studio
pause
exit /b 0

:failed
echo.
echo Something failed above. Copy the red error text, or run this again after fixing it.
pause
exit /b 1
