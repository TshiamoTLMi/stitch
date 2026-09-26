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
Run-Step -Name 'Focused Story Tests' -Command "$flutterCmd test test/services/auth_controller_test.dart test/widgets/login_recovery_test.dart test/services/recommendation_service_test.dart test/services/event_service_test.dart test/services/notification_service_test.dart test/widgets/dashboard_recommendation_test.dart test/services/profile_service_test.dart test/widgets/profile_insights_test.dart test/release_configuration_test.dart"
Run-Step -Name 'Flutter Android Debug Build' -Command "$flutterCmd build apk --debug"
Run-Step -Name 'Flutter Android Release Build' -Command "$flutterCmd build apk --release"
Run-Step -Name 'Flutter Web Release Build' -Command "$flutterCmd build web --release"

Write-Host "`nAll preflight checks passed." -ForegroundColor Green
