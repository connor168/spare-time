@echo off
setlocal EnableExtensions
set "ROOT=%~dp0.."
set /p FLUTTER_PREBUILT_ENGINE_VERSION=<"%ROOT%\.tools\flutter\bin\internal\engine.version"
set "RUNTIME=%ROOT%\.codex_flutter_runtime"
set "APPDATA=%RUNTIME%\appdata"
set "LOCALAPPDATA=%RUNTIME%\localappdata"
set "TEMP=%RUNTIME%\temp"
set "TMP=%RUNTIME%\temp"
set "PUB_CACHE=%RUNTIME%\pubcache"
set "USERPROFILE=%RUNTIME%"
set "HOME=%RUNTIME%"
call "%ROOT%\.tools\flutter\bin\flutter.bat" --no-version-check test --no-pub --concurrency=1
endlocal
