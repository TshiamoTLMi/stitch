param(
  [string]$FlutterPath = "C:\Users\TshiamoMoloto\Documents\flutter\bin\flutter.bat"
)

$ErrorActionPreference = 'Stop'

function Run-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )

  Write-Host "`n=== $Name ===" -ForegroundColor Cyan
  Invoke-Expression $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
  Write-Host "$Name passed" -ForegroundColor Green
}

if (-not (Test-Path $FlutterPath)) {
  throw "Flutter executable not found at: $FlutterPath"
}

$flutterCmd = "& `"$FlutterPath`""

Run-Step -Name 'Flutter Analyze' -Command "$flutterCmd analyze"
Run-Step -Name 'Flutter Test' -Command "$flutterCmd test"
Run-Step -Name 'Flutter Web Build' -Command "$flutterCmd build web --release"

Write-Host "`nAll preflight checks passed." -ForegroundColor Green
