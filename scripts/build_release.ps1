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

$signingProperties = ConvertFrom-StringData (Get-Content $keyProperties -Raw)
$storeFile = $signingProperties['storeFile']
$storePassword = $signingProperties['storePassword']
$keyAlias = $signingProperties['keyAlias']
$keyPassword = $signingProperties['keyPassword']
if ([string]::IsNullOrWhiteSpace($storeFile) -or
    [string]::IsNullOrWhiteSpace($storePassword) -or
    [string]::IsNullOrWhiteSpace($keyAlias) -or
    [string]::IsNullOrWhiteSpace($keyPassword)) {
  throw "android/key.properties must define storeFile, storePassword, keyAlias, and keyPassword."
}

$storePath = if ([IO.Path]::IsPathRooted($storeFile)) {
  $storeFile
} else {
  # Android's app module resolves storeFile relative to android/app.
  Join-Path (Join-Path $root 'android\app') $storeFile
}
$storePath = (Resolve-Path $storePath -ErrorAction Stop).Path

$env:APPDATA = Join-Path $root '.tools\appdata'
$env:LOCALAPPDATA = Join-Path $root '.tools\localappdata'
$env:JAVA_HOME = Join-Path $root '.tools\jdk-17'
$env:GRADLE_USER_HOME = Join-Path $root '.tools\gradle'
$keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
if (-not (Test-Path $keytool)) { throw "Java keytool not found at $keytool." }
$null = & $keytool -list -keystore $storePath -storepass $storePassword -alias $keyAlias 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Unable to validate the release keystore, alias, or password."
}
$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { throw 'Local Flutter SDK not found. Run scripts/bootstrap_flutter.py first.' }

& $flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Format -eq 'apk') { & $flutter build apk --release } else { & $flutter build appbundle --release }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
