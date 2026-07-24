$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
flutter pub get
flutter build apk --release
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $PSScriptRoot 'BMS_Group16_FULL_APP.apk') -Force
Write-Host 'APK ready: BMS_Group16_FULL_APP.apk'
