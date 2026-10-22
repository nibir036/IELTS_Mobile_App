@echo off
REM Sets up the database for the IELTS app and the nexted.app module.
REM Double-click this file. It asks for your PostgreSQL password and does the rest.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_nexted.ps1"
echo.
pause
