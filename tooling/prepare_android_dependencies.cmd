@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
set "MAVEN_ROOT=%ROOT%\.tools\local-maven"
set "GROUP_DIR=%MAVEN_ROOT%\com\tencent\mm\opensdk\wechat-sdk-android-without-mta\6.8.0"
set "AAR=%GROUP_DIR%\wechat-sdk-android-without-mta-6.8.0.aar"
set "POM=%GROUP_DIR%\wechat-sdk-android-without-mta-6.8.0.pom"
set "URL=http://repo.huaweicloud.com/repository/maven/com/tencent/mm/opensdk/wechat-sdk-android-without-mta/6.8.0/wechat-sdk-android-without-mta-6.8.0"

if not exist "%AAR%" (
  mkdir "%GROUP_DIR%" 2>nul
  curl.exe --fail --location --max-time 60 -o "%AAR%" "%URL%.aar"
  if errorlevel 1 exit /b 1
)
if not exist "%POM%" (
  curl.exe --fail --location --max-time 60 -o "%POM%" "%URL%.pom"
  if errorlevel 1 exit /b 1
)

for /f "tokens=*" %%H in ('certutil -hashfile "%AAR%" SHA256 ^| findstr /r /v "hash SHA256 CertUtil"') do set "HASH=%%H"
if /i not "%HASH%"=="abfea1a88844b0be00c9d6d6b1a54b70da5375abbbc10ac32a9960628e2624cf" (
  echo Unexpected WeChat SDK SHA-256: %HASH%
  exit /b 1
)

echo WeChat SDK ready: %AAR%
endlocal
