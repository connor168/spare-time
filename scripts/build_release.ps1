param(
  [ValidateSet('apk', 'appbundle')]
  [string]$Format = 'appbundle'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$keyProperties = Join-Path $root 'android\key.properties'
if (-not (Test-Path $keyProperties)) {
  throw "Missing $keyProperties. Copy android/key.properties.example and fill secrets locally."
}

$env:APPDATA = Join-Path $root '.tools\appdata'
$env:LOCALAPPDATA = Join-Path $root '.tools\localappdata'
$env:JAVA_HOME = Join-Path $root '.tools\jdk-17'
$env:GRADLE_USER_HOME = Join-Path $root '.tools\gradle'
$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { throw 'Local Flutter SDK not found. Run scripts/bootstrap_flutter.py first.' }

& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Format -eq 'apk') { & $flutter build apk --release } else { & $flutter build appbundle --release }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
