@echo off
REM IELTS AI by nextED - run the whole test suite.
REM Run from anywhere: it switches to the project folder itself.
REM Results: tool\test_report.txt
cd /d "%~dp0.."

echo Running flutter test (this takes a few minutes)...
call flutter test --reporter expanded > tool\test_report.txt 2>&1

echo.
echo Done. Results saved to tool\test_report.txt
pause
