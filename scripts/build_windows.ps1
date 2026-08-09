param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
$vsDevCmd = 'E:\Microsoft\Common7\Tools\VsDevCmd.bat'
if (-not (Test-Path $flutter)) { throw 'Local Flutter SDK not found. Run scripts/bootstrap_flutter.py first.' }
if (-not (Test-Path $vsDevCmd)) { throw 'Visual Studio developer command environment was not found.' }

$env:APPDATA = Join-Path $root '.tools\appdata'
$env:LOCALAPPDATA = Join-Path $root '.tools\localappdata'
$env:PUB_CACHE = Join-Path $root '.tools\pub-cache'
$env:JAVA_HOME = Join-Path $root '.tools\jdk-17'
$env:GRADLE_USER_HOME = Join-Path $root '.tools\gradle'
$env:TrackFileAccess = 'false'

$windowsKitRoot = 'E:\Windows Kits\10'
if (Test-Path (Join-Path $windowsKitRoot 'Lib\10.0.26100.0\ucrt\x64\ucrtd.lib')) {
  $env:UCRTContentRoot = "$windowsKitRoot\"
  $env:UniversalCRTSdkDir_10 = "$windowsKitRoot\"
  $env:TargetUniversalCRTVersion = '10.0.26100.0'
}

# The Windows app intentionally uses the in-memory repositories for desktop
# debug builds. Firebase and sqlite3_flutter_libs are mobile dependencies, but
# their Windows plugins try to download native SDKs during CMake configuration.
& $flutter pub get --offline
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$generatedCmakePath = Join-Path $root 'windows\flutter\generated_plugins.cmake'
$generatedCmake = [IO.File]::ReadAllText($generatedCmakePath)
$generatedCmakeOriginal = $generatedCmake
$generatedCmake = [Regex]::Replace(
  $generatedCmake,
  '(?m)^\s*(firebase_core|flutter_secure_storage_windows|sqlite3_flutter_libs)\s*\r?\n',
  '')
[IO.File]::WriteAllText($generatedCmakePath, $generatedCmake, [Text.UTF8Encoding]::new($false))

$registrantPath = Join-Path $root 'windows\flutter\generated_plugin_registrant.cc'
$registrant = [IO.File]::ReadAllText($registrantPath)
$registrantOriginal = $registrant
$registrant = [Regex]::Replace($registrant, '(?m)^#include <(firebase_core|flutter_secure_storage_windows|sqlite3_flutter_libs)/.*\r?\n', '')
$registrant = [Regex]::Replace($registrant, '(?s)\s+FlutterSecureStorageWindowsPluginRegisterWithRegistrar\(\s*registry->GetRegistrarForPlugin\("FlutterSecureStorageWindowsPlugin"\)\);\r?\n', '')
$registrant = [Regex]::Replace($registrant, '(?s)\s*FirebaseCorePluginCApiRegisterWithRegistrar\(.*?\);', '')
$registrant = [Regex]::Replace($registrant, '(?s)\s*Sqlite3FlutterLibsPluginRegisterWithRegistrar\(.*?\);', '')
[IO.File]::WriteAllText($registrantPath, $registrant, [Text.UTF8Encoding]::new($false))

$dartDefines = "--dart-define-from-file=config/local.json"
$flutterArgs = @('build', 'windows', "--$Mode", '--no-pub', $dartDefines)
$arguments = $flutterArgs | ForEach-Object {
  '"' + ([string]$_).Replace('"', '\"') + '"'
}
$environmentCommands = 'set "TrackFileAccess=false"'
if (Test-Path (Join-Path $windowsKitRoot 'Lib\10.0.26100.0\ucrt\x64\ucrtd.lib')) {
  $environmentCommands +=
    ' && set "UCRTContentRoot=' + $windowsKitRoot + '\"' +
    ' && set "UniversalCRTSdkDir_10=' + $windowsKitRoot + '\"' +
    ' && set "TargetUniversalCRTVersion=10.0.26100.0"' +
    ' && set "LIB=' + $windowsKitRoot + '\Lib\10.0.26100.0\ucrt\x64;' +
    $windowsKitRoot + '\Lib\10.0.26100.0\um\x64;E:\Microsoft\VC\Tools\MSVC\14.51.36231\lib\x64;E:\Microsoft\VC\Tools\MSVC\14.51.36231\ATLMFC\lib\x64"'
}
$command = 'call "' + $vsDevCmd + '" -arch=x64 -host_arch=x64 >nul && ' +
  $environmentCommands + ' && call "' + $flutter + '" ' +
  ($arguments -join ' ')
& $env:ComSpec /d /s /c $command
$buildExitCode = $LASTEXITCODE
[IO.File]::WriteAllText($generatedCmakePath, $generatedCmakeOriginal, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($registrantPath, $registrantOriginal, [Text.UTF8Encoding]::new($false))
exit $buildExitCode
