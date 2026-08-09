$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$config = Join-Path $root 'config\local.json'
$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $config)) { throw "Missing config/local.json. Copy config/local.json.example and fill in the public values." }
if (-not (Test-Path $flutter)) { throw 'Flutter SDK not found in .tools/flutter.' }

function ConvertTo-CmdArgument([string]$value) {
  return '"' + $value.Replace('"', '\"') + '"'
}

# MSBuild fails when the inherited environment contains both Path and PATH.
$pathEntry = [Environment]::GetEnvironmentVariables().GetEnumerator() |
  Where-Object { $_.Key -ceq 'Path' } |
  Select-Object -First 1
if ($null -eq $pathEntry) {
  $pathEntry = [Environment]::GetEnvironmentVariables().GetEnumerator() |
    Where-Object { $_.Key -match '(?i)^path$' } |
    Select-Object -First 1
}
[Environment]::SetEnvironmentVariable('PATH', $null, 'Process')
[Environment]::SetEnvironmentVariable('Path', [string]$pathEntry.Value, 'Process')

$env:APPDATA = Join-Path $root '.tools\appdata'
$env:LOCALAPPDATA = Join-Path $root '.tools\localappdata'
$env:PUB_CACHE = Join-Path $root '.tools\pub-cache'
$env:JAVA_HOME = Join-Path $root '.tools\jdk-17'
$env:GRADLE_USER_HOME = Join-Path $root '.tools\gradle'

if ($args -contains 'windows') {
  # VsDevCmd can inherit a stale 32-bit Windows SDK path on this machine.
  # Keep the workaround process-local; do not mutate the user's registry.
  $windowsKitRoot = 'E:\Windows Kits\10'
  if (Test-Path (Join-Path $windowsKitRoot 'Lib\10.0.26100.0\ucrt\x64\ucrtd.lib')) {
    $env:UCRTContentRoot = "$windowsKitRoot\"
    $env:UniversalCRTSdkDir_10 = "$windowsKitRoot\"
    $env:TargetUniversalCRTVersion = '10.0.26100.0'
  }
  $env:TrackFileAccess = 'false'
  $vsDevCmd = 'E:\Microsoft\Common7\Tools\VsDevCmd.bat'
  if (-not (Test-Path $vsDevCmd)) { throw 'Visual Studio developer command environment was not found.' }
  $flutterArgs = @('run', "--dart-define-from-file=$config") + @($args)
  $command = 'call ' + (ConvertTo-CmdArgument $vsDevCmd) +
    ' -arch=x64 -host_arch=x64 >nul && call ' +
    (ConvertTo-CmdArgument $flutter) + ' ' +
    (($flutterArgs | ForEach-Object { ConvertTo-CmdArgument $_ }) -join ' ')
  & $env:ComSpec /d /s /c $command
  exit $LASTEXITCODE
}

& $flutter run --dart-define-from-file=$config @args
exit $LASTEXITCODE
