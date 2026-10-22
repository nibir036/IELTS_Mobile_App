@echo off
REM Double-click this file. It starts the API server, opens a public address
REM for it, points the app at that address and builds the APK - the four
REM steps that used to be typed by hand in three windows.
title IELTS AI - demo build
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_demo.ps1"
echo.
pause
