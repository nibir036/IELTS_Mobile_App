@echo off
REM IELTS AI by nextED - one-time cleanup of the old app code + analyze.
REM Run from anywhere: it switches to the project folder itself.
cd /d "%~dp0.."

echo Removing old app code (still recoverable from git history)...
for %%D in (
  lib\core
  lib\features\auth
  lib\features\mock_tests
  lib\features\practice
  lib\features\settings
  lib\features\submissions
  lib\features\home\data lib\features\home\screens lib\features\home\state lib\features\home\widgets
  lib\features\listening\data lib\features\listening\screens lib\features\listening\state
  lib\features\reading\data lib\features\reading\screens lib\features\reading\state
  lib\features\speaking\data lib\features\speaking\screens lib\features\speaking\state
  lib\features\writing\data lib\features\writing\screens lib\features\writing\state
  assets\videos
  android\app\src\main\kotlin\com\example
) do if exist "%%D" rmdir /s /q "%%D"

echo Running flutter pub get...
call flutter pub get > tool\analyze_report.txt 2>&1
echo. >> tool\analyze_report.txt
echo ===== flutter analyze ===== >> tool\analyze_report.txt
call flutter analyze --no-fatal-infos >> tool\analyze_report.txt 2>&1
echo. >> tool\analyze_report.txt
echo ===== flutter test ===== >> tool\analyze_report.txt
call flutter test >> tool\analyze_report.txt 2>&1

echo.
echo Done. Results saved to tool\analyze_report.txt
pause
