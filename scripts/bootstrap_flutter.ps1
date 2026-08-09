[CmdletBinding()]
param(
  [string]$Channel = 'stable',
  [string]$InstallRoot = (Join-Path $PSScriptRoot '..\.tools'),
  [string]$ReleaseMetadataUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
  Write-Host "[flutter-bootstrap] $Message"
}

function Get-ReleaseArchive {
  param(
    [Parameter(Mandatory = $true)] $Metadata,
    [Parameter(Mandatory = $true)] [string]$RequestedChannel
  )

  $releases = @($Metadata.releases)
  if (-not $releases.Count) {
    throw 'Release metadata did not contain any releases.'
  }

  $selected = $null
  if ($Metadata.current_release -and $Metadata.current_release.$RequestedChannel) {
    $currentRef = $Metadata.current_release.$RequestedChannel
    $selected = $releases | Where-Object { $_.hash -eq $currentRef -or $_.version -eq $currentRef } | Select-Object -First 1
  }

  if (-not $selected) {
    $selected = $releases | Where-Object { $_.channel -eq $RequestedChannel } | Sort-Object release_date -Descending | Select-Object -First 1
  }

  if (-not $selected) {
    throw "Unable to find a release for channel '$RequestedChannel'."
  }

  return $selected
}

function Resolve-ArchiveUrl {
  param(
    [Parameter(Mandatory = $true)] $Metadata,
    [Parameter(Mandatory = $true)] $Release
  )

  if ($Release.url) {
    return [string]$Release.url
  }

  $baseUrl = [string]$Metadata.base_url
  if (-not $baseUrl) {
    $baseUrl = 'https://storage.googleapis.com/flutter_infra_release/releases'
  }

  $archivePath = [string]$Release.archive
  if (-not $archivePath) {
    $archivePath = "stable/windows/flutter_windows_$($Release.version)-stable.zip"
  }

  return ($baseUrl.TrimEnd('/') + '/' + $archivePath.TrimStart('/'))
}

Write-Info "Reading release metadata from $ReleaseMetadataUrl"
$metadata = Invoke-WebRequest -Uri $ReleaseMetadataUrl -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$release = Get-ReleaseArchive -Metadata $metadata -RequestedChannel $Channel
$archiveUrl = Resolve-ArchiveUrl -Metadata $metadata -Release $release

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
$archiveName = Split-Path -Path $archiveUrl -Leaf
$archivePath = Join-Path $env:TEMP $archiveName

Write-Info "Selected release: $($release.version) ($($release.channel))"
Write-Info "Downloading $archiveUrl"
Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath

if ($release.sha256) {
  $actualHash = (Get-FileHash -Algorithm SHA256 -Path $archivePath).Hash.ToLowerInvariant()
  $expectedHash = [string]$release.sha256
  if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
    Remove-Item -Force $archivePath
    throw "Checksum mismatch for $archiveName. Expected $expectedHash but got $actualHash."
  }
}

Write-Info "Extracting to $InstallRoot"
Expand-Archive -Path $archivePath -DestinationPath $InstallRoot -Force

$flutterRoot = Join-Path $InstallRoot 'flutter'
$flutterBat = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path $flutterBat)) {
  throw "Flutter executable not found at $flutterBat"
}

Write-Info "Bootstrap complete."
Write-Info "SDK location: $flutterRoot"
Write-Info "Run: `"$flutterBat doctor`""
