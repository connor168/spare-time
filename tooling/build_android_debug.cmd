@echo off
setlocal EnableExtensions
set "ROOT=%~dp0.."
call "%~dp0prepare_android_dependencies.cmd"
if errorlevel 1 exit /b 1

set "RUNTIME=%ROOT%\.codex_flutter_runtime"
set "APPDATA=%RUNTIME%\appdata"
set "LOCALAPPDATA=%RUNTIME%\localappdata"
set "TEMP=%RUNTIME%\temp"
set "TMP=%RUNTIME%\temp"
set "PUB_CACHE=%RUNTIME%\pubcache"
set "USERPROFILE=%RUNTIME%"
set "HOME=%RUNTIME%"
set "ANDROID_HOME=%ROOT%\.tools\android-sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "JAVA_HOME=%ROOT%\.tools\jdk-17"
set "GRADLE_USER_HOME=%ROOT%\.tools\gradle"
set "FOCUS_FLOW_LOCAL_MAVEN=%ROOT%\.tools\local-maven"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "GRADLE_OPTS=-Dorg.gradle.offline=true"

call "%ROOT%\.tools\flutter\bin\flutter.bat" --no-version-check build apk --debug --no-pub
endlocal
