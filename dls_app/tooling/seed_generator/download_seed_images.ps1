# Downloads the CC0 seed images declared by the generator into assets/seed/images/.
#
# Source: Wikimedia Commons "Europeana Fashion - MoMu - Thesaurus drawings"
# Licence: CC0 1.0 (Public Domain Dedication), AttributionRequired = false.
#
# Run from the package root:
#   dart run tooling/seed_generator/main.dart      # writes the download plan
#   pwsh -File tooling/seed_generator/download_seed_images.ps1
param(
  [string]$Manifest = "tooling/seed_generator/seed_image_downloads.json",
  [string]$OutDir   = "assets/seed/images",
  [int]$DelayMs     = 1500,
  [int]$MaxAttempts = 5,
  [string]$UserAgent = "DLS-SeedGenerator/1.0 (DLS dev seed; contact: repo maintainer)"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Manifest)) {
  throw "Manifest not found: $Manifest. Run 'dart run tooling/seed_generator/main.dart' first."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$plan = Get-Content $Manifest -Raw | ConvertFrom-Json
$items = @($plan.images.PSObject.Properties)

$ok = 0; $skip = 0; $fail = 0
foreach ($p in $items) {
  $local = $p.Name
  $url = [string]$p.Value
  $dest = Join-Path $OutDir $local

  if (Test-Path $dest) {
    $skip++
    Write-Host "skip       $local (already present)"
    continue
  }

  $attempt = 0
  $done = $false
  while (-not $done) {
    $attempt++
    try {
      Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 60 `
        -Headers @{ 'User-Agent' = $UserAgent } | Out-Null
      $size = (Get-Item $dest).Length
      if ($size -le 0) { throw "downloaded file is empty" }
      $ok++
      $done = $true
      Write-Host "downloaded $local ($size bytes)"
    } catch {
      if (Test-Path $dest) { Remove-Item $dest -Force }
      if ($attempt -ge $MaxAttempts) {
        $fail++
        $done = $true
        Write-Host "FAILED     $local : $($_.Exception.Message)"
      } else {
        $backoff = $DelayMs * $attempt
        Write-Host "retry      $local (attempt $attempt/$MaxAttempts) in ${backoff}ms"
        Start-Sleep -Milliseconds $backoff
      }
    }
  }

  Start-Sleep -Milliseconds $DelayMs
}

Write-Host "done: ok=$ok skipped=$skip failed=$fail total=$($items.Count)"
if ($fail -gt 0) { exit 1 }
