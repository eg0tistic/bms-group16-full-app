$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
flutter pub get
flutter run -d chrome
