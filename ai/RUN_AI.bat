@echo off
REM nextED AI service (AI Counsellor, Course Finding, Scholarship Finding).
REM Double-click to start it on http://127.0.0.1:8000  (API docs: /docs).
REM First run: makes a Python virtual environment and installs the packages.
REM The IELTS app's API server (port 4000) calls this one; keep both open.
cd /d "%~dp0"

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY (
  where python >nul 2>nul && set "PY=python"
)
if not defined PY (
  echo Python was not found. Install Python 3.11 or newer from https://www.python.org/downloads/
  echo and tick "Add python.exe to PATH" in the installer. Then run this again.
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo ===== Creating the virtual environment =====
  %PY% -m venv .venv
  if errorlevel 1 goto failed
)

echo ===== Installing / checking packages =====
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -q -r requirements.txt
if errorlevel 1 goto failed

if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo A new .env was created from .env.example - add your keys to it.
)

REM Knowledge base: share the IELTS app's database. DATABASE_URL is copied
REM from ..\server\.env (no password is kept in this file). The service puts
REM its tables in their own schema, "nexted_ai", away from Prisma's tables.
set "DATABASE_URL="
if exist "..\server\.env" (
  for /f "usebackq tokens=1,* delims==" %%A in ("..\server\.env") do (
    if /i "%%A"=="DATABASE_URL" set "DATABASE_URL=%%~B"
  )
)
if defined DATABASE_URL (
  echo Knowledge base: the IELTS database from server\.env, schema nexted_ai
) else (
  echo Knowledge base: no DATABASE_URL in ..\server\.env - using ai\.env or the JSON files
)

echo.
echo ===== nextED AI is starting on http://127.0.0.1:8000 =====
echo Check it:  http://127.0.0.1:8000/health    Try it:  http://127.0.0.1:8000/docs
echo Keep this window open. Ctrl+C stops it.
echo.
".venv\Scripts\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
pause
exit /b 0

:failed
echo.
echo Something failed above. Copy the red lines and send them to Claude.
pause
exit /b 1
