param([string]$Alias = 'focus-flow-upload')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = Join-Path $root '.tools\jdk-17'
$keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
$keystore = Join-Path $root 'android\focus-flow-upload.jks'
$properties = Join-Path $root 'android\key.properties'
if (-not (Test-Path $keytool)) { throw 'JDK 17 keytool not found in .tools/jdk-17.' }
if (Test-Path $keystore) { throw "Keystore already exists at $keystore. Do not overwrite it." }

$securePassword = Read-Host 'Enter a keystore password' -AsSecureString
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
$env:FOCUS_FLOW_KEYSTORE_PASSWORD = $plainPassword
$env:FOCUS_FLOW_KEY_PASSWORD = $plainPassword
try {
  & $keytool -genkeypair -v -keystore $keystore -alias $Alias -keyalg RSA -keysize 4096 -validity 10000 -storepass:env FOCUS_FLOW_KEYSTORE_PASSWORD -keypass:env FOCUS_FLOW_KEY_PASSWORD -dname 'CN=Focus Flow, OU=Mobile, O=Focus Flow, L=Unknown, ST=Unknown, C=CN'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  # Gradle resolves storeFile relative to android/app, while the private key is
  # intentionally kept one directory higher under android/.
  @("storeFile=../focus-flow-upload.jks", "storePassword=$plainPassword", "keyAlias=$Alias", "keyPassword=$plainPassword") | Set-Content -LiteralPath $properties -Encoding ascii
} finally {
  Remove-Item Env:FOCUS_FLOW_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:FOCUS_FLOW_KEY_PASSWORD -ErrorAction SilentlyContinue
  $plainPassword = $null
}
Write-Host "Created $keystore and $properties. Keep both private and back up the keystore securely."
