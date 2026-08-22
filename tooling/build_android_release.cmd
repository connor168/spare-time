@echo off
setlocal EnableExtensions
set "ROOT=%~dp0.."
call "%~dp0prepare_android_dependencies.cmd"
if errorlevel 1 exit /b 1

rem Flutter's bundled checkout may be owned by the Codex sandbox account.
rem Supplying the pinned engine hash avoids a Git safe-directory lookup.
set /p FLUTTER_PREBUILT_ENGINE_VERSION=<"%ROOT%\.tools\flutter\bin\internal\engine.version"
if not defined FLUTTER_PREBUILT_ENGINE_VERSION (
  echo Unable to read Flutter engine.version.
  exit /b 1
)

if not exist "%ROOT%\android\key.properties" (
  echo Missing android\key.properties. Release signing is required.
  exit /b 1
)

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
set "GRADLE_OPTS=-Djava.net.preferIPv4Stack=true -Dhttps.protocols=TLSv1.2"

call "%ROOT%\.tools\flutter\bin\flutter.bat" --no-version-check build apk --release --no-pub
endlocal
