@echo off
rem Store build of IELTS AI by nextED with code obfuscation, pointed at the live API.
rem   tool\build_release.bat              (APK for testing on a phone)
rem   tool\build_release.bat apk          (same)
rem   tool\build_release.bat appbundle    (AAB for the Play Store)
rem
rem The live API address (https://mobile-api.nexted.app) is added automatically.
rem Without it the app would run offline with demo data and show the demo login.
rem To use another server, pass your own: --dart-define=API_BASE_URL=https://...
rem
rem --obfuscate renames classes and functions in the compiled Dart code, so a
rem decompiled APK does not show readable names. The map to read crash
rem reports back is written to build\symbols: keep it (per version), never
rem ship or upload it anywhere public.

set "LIVE_API=https://mobile-api.nexted.app"
set "ARGS=%*"
if "%~1"=="" set "ARGS=apk"

echo %ARGS% | findstr /C:"API_BASE_URL" >nul
if errorlevel 1 set "ARGS=%ARGS% --dart-define=API_BASE_URL=%LIVE_API%"

echo Building: flutter build %ARGS%
flutter build %ARGS% --release --obfuscate --split-debug-info=build\symbols
