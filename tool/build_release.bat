@echo off
rem Store build of IELTS AI by nextED with code obfuscation.
rem   tool\build_release.bat apk        (APK for testing on a phone)
rem   tool\build_release.bat appbundle  (AAB for the Play Store)
rem Extra flags are passed through, e.g. the API address:
rem   tool\build_release.bat apk --dart-define=API_BASE_URL=https://mobile-api.nexted.app
rem
rem --obfuscate renames classes and functions in the compiled Dart code, so a
rem decompiled APK does not show readable names. The map to read crash
rem reports back is written to build\symbols: keep it (per version), never
rem ship or upload it anywhere public.

if "%~1"=="" (
  flutter build apk --release --obfuscate --split-debug-info=build\symbols
) else (
  flutter build %* --release --obfuscate --split-debug-info=build\symbols
)
